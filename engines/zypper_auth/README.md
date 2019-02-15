# ZypperAuth

1. Instance supplies instance data during registration, if it contains `<repoformat>plugin:susecloud</repoformat>` then service URLs are returned with `plugin:` scheme, e.g. `plugin:/susecloud?credentials=Example&path=/service/42>`
2. When zypper tries to access `plugin:/susecloud` URLs, it calls `susecloud` URL resolver plugin installed on the client, which appends authentication headers to the request
3. Service XML endpoint returns repository URLs in `plugin:/susecloud` format when the request has `X-Instance-Data` header

