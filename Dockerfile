FROM elixir:1.14-slim

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

ADD mix.exs .
ADD mix.lock .

ENV MIX_ENV=prod

RUN set -ex \
	&& apt update \
	&& apt upgrade -y \
	&& apt install -y build-essential git \
 	&& mix local.hex --force \
 	&& mix local.rebar --force \
 	&& mix deps.get --only prod \
	&& mix compile 

ADD . .

RUN set -ex \
 	&& mix deps.get --only prod \
	&& mix compile \
	&& mix assets.deploy

EXPOSE 4000

ENTRYPOINT ["mix"]
CMD ["phx.server"]
