# data-modelling

This is a repo with a dev container. So, the easiest way is to open this repo after cloning, with Visual Studio Code with Dev Containers extension support.

When the dev container is running you can use this command in the terminal window to execute the scripts:
```
psql -h localhost -U postgres -f <script.sql>
```

The PostgreSQL database is also accessible through your host. You can use DBeaver for example, to connect using:
- host: localhost
- user: postgres
- password: postgres
- database: postgres
