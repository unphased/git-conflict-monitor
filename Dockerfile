from alpine:3.15

RUN apk update && apk add git bash file

COPY index.sh /opt/git-conflict-monitor.sh

RUN mkdir -p /opt/git-conflict-monitor-repos
RUN mkdir -p /opt/git-conflict-monitor-metadata

CMD /opt/git-conflict-monitor.sh

# bindmount in the sensitive bits (REPO env var and git creds)
