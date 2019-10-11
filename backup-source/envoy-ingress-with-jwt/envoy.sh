#!/bin/sh
cp /keys/public/ca-certs/*.crt /usr/local/share/ca-certificates/
update-ca-certificates

restart_epoch=$(ps | grep -Ei 'envoy.yaml --restart-epoch' | grep -v 'grep' | sed 's/^.*--restart-epoch \([0-9]*\) --.*$/\1/' | tail -1)
if [ "x$restart_epoch" = "x" ]; then restart_epoch=0; else restart_epoch=$((restart_epoch+1)); fi

/usr/local/bin/envoy \
    -c /etransfer/esg/conf/envoy.yaml \
    --restart-epoch $restart_epoch \
    --log-level $ENVOY_LOG_LEVEL \
    --service-cluster esg \
    --file-flush-interval-msec 2000 \
    --drain-time-s 60 \
    --parent-shutdown-time-s 90
