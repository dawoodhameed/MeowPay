FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY pubspec.yaml ./
RUN flutter pub get
COPY . .
RUN flutter build web

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
