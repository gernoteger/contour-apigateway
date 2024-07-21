# small for locla buiöd
FROM busybox
WORKDIR /usr/src/app


COPY target/test .

ENTRYPOINT [ "./test" ]
CMD ["-test.v" ]