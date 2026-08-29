FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY pubspec.yaml ./
RUN flutter pub get
COPY . .
RUN flutter build web

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
# Proxies /api to the backend so the browser makes only same-origin requests.
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
