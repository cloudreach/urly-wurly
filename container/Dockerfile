FROM ruby:2.6.3-alpine

WORKDIR "/app"

ADD "public/" "."
ADD "public/index.html" "public/"
ADD "server.rb" "."
ADD "Gemfile" "."

RUN ["bundle", "install"]

ENTRYPOINT ["ruby", "./server.rb"]
