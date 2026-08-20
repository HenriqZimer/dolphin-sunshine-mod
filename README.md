# dolphin-sunshine-mod

Docker Mod (formato "Universal Mods" da linuxserver.io) que instala e roda o
[Sunshine](https://github.com/LizardByte/Sunshine) dentro do container
`lscr.io/linuxserver/dolphin`, ao lado do Selkies/KasmVNC que a imagem já
traz. POC pra comparar input lag/latência do streaming via Moonlight contra
o streaming atual via navegador (Selkies).

## ⚠️ Requer `PIXELFLUX_WAYLAND=false`

A imagem roda em **modo Wayland por padrão** (`PIXELFLUX_WAYLAND=true` é o
default do próprio Dockerfile da imagem — confirmado via `docker inspect`).
Em modo Wayland, o `svc-xorg` nem chega a subir o Xvfb. O Sunshine no Linux
não tem suporte robusto a Wayland (só X11/KMS/NvFBC), então **este mod só
funciona com `PIXELFLUX_WAYLAND=false`** setado no env do pod, forçando o
Xvfb a subir de verdade em `:1`.

Validado localmente (sem GPU): com `PIXELFLUX_WAYLAND=false` o Sunshine loga
`Screencasting with X11` e captura corretamente, caindo pro encoder de
software na ausência de GPU. Sem essa env var, o `run` do mod trava
esperando o Xvfb e loga um aviso claro após 60s em vez de ficar preso pra
sempre sem explicação.

**Atenção**: isso muda o backend de captura do Selkies também (que hoje
roda em modo Wayland em produção) — vale confirmar, ao testar, que o
streaming via navegador (KasmVNC) continua funcionando normalmente em modo
X11 antes de considerar isso "sem regressão".

## Por que a captura funciona sem configuração extra de display

O `svc-xorg` da imagem roda **Xvfb** (X puramente por software, sem bind
real de KMS/DRM) em `DISPLAY=:1` — esse valor já vem fixo como `ENV` na
imagem. O Sunshine, na ausência de um display KMS real, cai automaticamente
para captura via X11/XSHM (o mesmo caminho que o Selkies já usa) e usa a GPU
só para o encode (NVENC), então basta rodar como mais um serviço s6 no
mesmo container — ele herda `DISPLAY` do ambiente.

## Limitação conhecida (aceitável para a POC)

O filesystem do container é efêmero — só `/config` (e as libraries do RomM)
são PVC. O `run` deste mod reinstala o Sunshine via `apt` toda vez que o pod
reinicia/recria, não só na primeira vez. Para produção valeria a pena trocar
por uma imagem própria com o Sunshine já embutido no build, em vez de
instalar em runtime.

## Uso

```yaml
env:
  DOCKER_MODS: "ghcr.io/loneangelfayt/dolphin-romm-integration-mod:latest|ghcr.io/<seu-usuario>/dolphin-sunshine-mod:latest"
  PIXELFLUX_WAYLAND: "false"  # obrigatorio - ver secao acima
```

(mods são aplicados em ordem, separados por `|`)

## Teste local (sem publicar) via sideload

O framework de Docker Mods busca a imagem de um registry real por padrão -
não existe forma de apontar `DOCKER_MODS` pra uma imagem só local no
`docker images`. Pra testar sem publicar em lugar nenhum, use o modo
sideload, que lê o mod de uma pasta montada:

```bash
docker run -d --name dolphin-poc \
  -e DOCKER_MODS=dolphin-sunshine-mod \
  -e DOCKER_MODS_SIDELOAD=true \
  -e PIXELFLUX_WAYLAND=false \
  -e PUID=1000 -e PGID=1000 -e TZ=Etc/UTC \
  --shm-size=2g \
  -v "$(pwd)/root:/mods/dolphin-sunshine-mod:ro" \
  lscr.io/linuxserver/dolphin:latest
```

Verificação rápida:

```bash
# serviço subiu?
docker exec dolphin-poc s6-svstat /run/service/svc-sunshine

# Sunshine escutando?
docker exec dolphin-poc ss -tlnp | grep -E '4798[0-9]|4799[0-9]'

# capturou X11 certo? (procurar "Screencasting with X11")
docker exec dolphin-poc cat /config/.config/sunshine/sunshine.log
```

## Build & publish

```bash
docker build -t ghcr.io/<seu-usuario>/dolphin-sunshine-mod:latest .
docker push ghcr.io/<seu-usuario>/dolphin-sunshine-mod:latest
```

## Portas do Sunshine (Moonlight)

Precisam de um `Service` `LoadBalancer` dedicado (Traefik só tem entrypoints
HTTP/HTTPS, não passa TCP/UDP cru do Moonlight):

| Porta | Protocolo | Uso |
|---|---|---|
| 47989 | TCP | HTTP (pareamento/descoberta) |
| 47984 | TCP | HTTPS |
| 47990 | TCP | UI web do Sunshine |
| 48010 | TCP | RTSP |
| 47998 | UDP | Vídeo |
| 47999 | UDP | Controle |
| 48000 | UDP | Áudio |
| 48002 | UDP | Microfone (opcional) |
