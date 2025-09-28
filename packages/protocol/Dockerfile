FROM node:22

WORKDIR /app

COPY . .

RUN apt-get update && apt-get install -y jq

RUN git init && \
    curl -L https://foundry.paradigm.xyz | bash && \
    npm install -g pnpm

ENV PATH="/root/.foundry/bin:$PATH"

RUN foundryup -i 1.2.3 && \
    forge install && \
    pnpm install

RUN find /app/script -type f -name "*.sh" -exec chmod +x {} \;

CMD ["sh", "-c", "echo Please verify the environment variables and command."]