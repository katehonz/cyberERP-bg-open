# Build stage
FROM hexpm/elixir:1.14.5-erlang-26.2.2-debian-bullseye-20240130 AS build

RUN apt-get update -y && apt-get install -y build-essential git npm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
COPY apps/cyber_core/mix.exs apps/cyber_core/
COPY apps/cyber_web/mix.exs apps/cyber_web/

RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY apps/cyber_core/priv apps/cyber_core/priv
COPY apps/cyber_core/lib apps/cyber_core/lib
COPY apps/cyber_web/priv apps/cyber_web/priv
COPY apps/cyber_web/lib apps/cyber_web/lib
COPY apps/cyber_web/assets apps/cyber_web/assets

# Install npm dependencies for assets
RUN cd apps/cyber_web/assets && npm install

RUN cd apps/cyber_web && mix assets.deploy

RUN mix compile

COPY config/runtime.exs config/

RUN mix release

# Production stage
FROM debian:bullseye-slim AS app

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales wkhtmltopdf \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody:nogroup /app

ENV MIX_ENV=prod

COPY --from=build --chown=nobody:nogroup /app/_build/${MIX_ENV}/rel/cyber_erp ./

USER nobody

CMD ["/app/bin/cyber_erp", "start"]
