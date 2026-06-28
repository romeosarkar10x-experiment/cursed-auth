FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99

RUN apt-get update && apt-get install -y \
    xvfb fluxbox x11vnc websockify \
    curl unzip fonts-liberation libnss3 libatk-bridge2.0-0 \
    libdrm2 libxcomposite1 libxdamage1 libxrandr2 libgbm1 \
    libpango-1.0-0 libasound2t64 libcups2 libxkbcommon0 \
    wget xz-utils libatomic1

RUN apt-get install -y novnc
RUN apt-get remove -y nodejs

RUN rm -rf /var/lib/apt/lists/*

WORKDIR /root

RUN wget https://nodejs.org/dist/v26.4.0/node-v26.4.0-linux-x64.tar.xz
RUN tar -xf node-v26.4.0-linux-x64.tar.xz

ENV PATH="/root/node-v26.4.0-linux-x64/bin:$PATH"

RUN node -v

RUN wget -qO- https://get.pnpm.io/install.sh | ENV="$HOME/.dashrc" SHELL="$(which dash)" dash -

ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME/bin:$PATH"

RUN pnpm -v

WORKDIR /cursed_auth

COPY package.json ./
COPY pnpm-lock.yaml ./
COPY pnpm-workspace.yaml ./

RUN pnpm install

COPY . .
RUN pnpm run build

RUN pnpm exec playwright install chromium --with-deps 2>/dev/null

ENV PATH="/cursed_auth:$PATH"
ENTRYPOINT ["entrypoint.sh"]

EXPOSE 6080
