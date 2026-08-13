FROM nginxinc/nginx-unprivileged:1.27-alpine

COPY index.html /usr/share/nginx/html/index.html
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

ENV BACKEND_HOST=backend:8080
EXPOSE 8080
