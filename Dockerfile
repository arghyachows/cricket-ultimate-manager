# Stage 1: Build Flutter Web
FROM debian:bookworm-slim AS build

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter doctor
RUN flutter config --enable-web

# Copy project files
WORKDIR /app
COPY . .

# Build for web
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config (Listen on $PORT if provided, else 8080)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy Flutter web build from build stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Render injects PORT, but Nginx config usually uses a hardcoded one or needs envsubst
# For simplicity, we'll keep 8080 and tell Render to use it, or update nginx.conf
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
