from alpine:3.15

RUN apk add --update --no-cache git bash file python3 coreutils openssh sudo

RUN adduser --disabled-password bot && adduser bot wheel \
  && sed -e 's;^# \(%wheel.*NOPASSWD.*\);\1;g' -i /etc/sudoers \
  && mkdir -p /opt/git-conflict-monitor/repos /opt/git-conflict-monitor/metadata /opt/git-conflict-monitor/results \
  && chown -R bot:bot /opt/git-conflict-monitor

COPY --chown=bot index.sh /opt/git-conflict-monitor.sh

USER bot

RUN mkdir -p /home/bot/.ssh \
  && git config --global user.name "git-conflict-monitor" \
  && git config --global user.email "bot@gcm_bot" \
  && git config --global advice.detachedHead false

CMD /opt/git-conflict-monitor.sh

# bindmount in the sensitive bits (REPO env var and git creds files)
