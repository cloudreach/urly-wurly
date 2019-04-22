FROM ruby:2.6.3-alpine

RUN ["gem", "install", "sinatra"]
WORKDIR "/app"
ADD "server.rb" "."

ENTRYPOINT ["ruby", "./server.rb"]
