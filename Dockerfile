# Universal Docker Mod (padrao linuxserver.io): a imagem nao roda sozinha,
# so serve pra ter seu filesystem sobreposto no container alvo no boot
# (via DOCKER_MODS). Ver https://github.com/linuxserver/docker-mods
FROM scratch

COPY root/ /
