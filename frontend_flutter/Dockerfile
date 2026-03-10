# Use pre-built Flutter web assets (already compiled locally in build/web)
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
