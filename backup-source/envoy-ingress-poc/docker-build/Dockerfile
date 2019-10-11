FROM envoyproxy/envoy-alpine:latest

# for usermod command, timezone and ca-certs
RUN apk --no-cache add shadow tzdata ca-certificates

RUN addgroup -g 610 -S bnlapp && \
    adduser -u 610 -S bnlapp -G bnlapp

# may not required for all groups below.
RUN usermod -a -G root,bin,daemon,sys bnlapp

# have to create the folder and pur the config file under. Or, the volume will not be accessible by container.
RUN mkdir /home/bnlapp/envoy-ingress &&\
	mkdir /home/bnlapp/envoy-ingress &&\
	mkdir /home/bnlapp/envoy-ingress/ssl &&\
	mkdir /home/bnlapp/envoy-ingress/conf &&\
	mkdir /home/bnlapp/envoy-ingress/logs

# config will be mounted from host
#ADD envoy-ingress.yaml /etc/envoy/envoy-ingress.yaml

# Copy Lua scripts
COPY src/lua/ /usr/local/share/lua/5.1/

# make the Alpine OS knows the self-signed root CA certs. maybe not necessary.
#### RUN apk add --no-cache ca-certificates    ---- add together at the beginning
#### RUN mkdir /usr/local/share/ca-certificates    ---- existing already
ADD ca-certs/*.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates

# Add SSL keys ---- mount the certs from the volume
# ADD envoy-ingress-ssl.crt /home/bnlapp/envoy-ingress/ssl/envoy-ingress-ssl.crt
# ADD envoy-ingress-ssl.key /home/bnlapp/envoy-ingress/ssl/envoy-ingress-ssl.key

RUN chown -R bnlapp:bnlapp /home/bnlapp

USER bnlapp
WORKDIR  /home/bnlapp

# Envoy uses UTC no matter what. But this env-var will help if you log into the instance for troubleshooting.
ENV TZ America/Toronto

#CMD tail -f /dev/null
#CMD /usr/local/bin/envoy -c /etc/envoy/envoy-ingress.yaml --service-cluster envoy-ingress
CMD /usr/local/bin/envoy -c /home/bnlapp/envoy-ingress/conf/envoy-ingress.yaml --service-cluster envoy-ingress -l debug
