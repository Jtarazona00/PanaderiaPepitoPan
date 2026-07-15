# Imagen del frontend (nginx sirviendo el sitio estático en el puerto 8080).
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 8080
