# Serves a pre-built Flutter web bundle (see openshift/deploy.sh).
FROM docker.io/nginxinc/nginx-unprivileged:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY web/ /usr/share/nginx/html/
EXPOSE 8080
