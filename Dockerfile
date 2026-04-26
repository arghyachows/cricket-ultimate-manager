# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:3.29.0 AS build

WORKDIR /app

# Disable analytics and pre-fetch artifacts
RUN flutter config --no-analytics && \
    flutter doctor

# Copy only pubspec first to cache dependencies
COPY pubspec.* ./
RUN flutter pub get

# Copy the rest of the code
COPY . .

# Run build with verbose output to catch errors
RUN flutter build web --release --no-pub -v

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
