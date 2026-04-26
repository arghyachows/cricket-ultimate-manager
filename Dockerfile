# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Run build
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy Flutter web build from build stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Render defaults
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
