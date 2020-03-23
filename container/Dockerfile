# build stage
FROM golang AS build-env
WORKDIR /src/
ADD server.go /src/
RUN cd /src && CGO_ENABLED=0 GOOS=linux GOARCH=amd64  go build -tags netgo -a -installsuffix cgo -o server

# final stage
FROM alpine
EXPOSE 80
WORKDIR /app/
COPY --from=build-env /src/server /app/
ADD ./public /app/public/
ENTRYPOINT /app/server