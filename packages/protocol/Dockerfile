FROM node:22

WORKDIR /app

COPY . .

RUN apt-get update && apt-get install -y jq

RUN git init && \
    curl -L https://foundry.paradigm.xyz | bash && \
    npm install -g pnpm && \
    . ~/.bashrc && \
    foundryup && \
    forge install && \
    pnpm install

ENV PATH="/root/.foundry/bin:$PATH"

CMD ["sh", "-c", "echo Please verify the environment variables and command."]
