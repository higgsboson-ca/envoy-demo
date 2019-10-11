FROM artifactory.interac.ca:5001/interac-docker-npr/envoyproxy/envoy-alpine:latest

# For usermod command, timezone, and ca-certs.
RUN apk --no-cache add shadow tzdata ca-certificates supervisor

# Create the target folders that must be volume-mounted but accessible by the container.
RUN mkdir -p /etransfer && \
    mkdir /etransfer/esg && \
	mkdir /etransfer/esg/conf && \
    mkdir /etransfer/esg/logs && \
    mkdir -p /keys && \
    mkdir /keys/public && \
    mkdir /keys/private

# Copy runtime scripts.
COPY src/lua/ /usr/local/share/lua/5.1/
COPY *.sh /etransfer/esg/
COPY supervisord.conf /etransfer/esg/

WORKDIR /etransfer/esg

RUN chmod 755 *.sh

# Envoy uses UTC no matter what, but this env-var will help when logging into the instance for troubleshooting.
ENV TZ America/Toronto

CMD ["supervisord", "-c", "/etransfer/esg/supervisord.conf"]
