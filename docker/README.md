# Windchill 13.1 + OpenDJ + SQL Server (Docker)

1. Copier le média PTC Windchill 13.1 décompressé dans ./media
2. Adapter .env (mots de passe, PSI_INSTALL_CMD) et windchill/hooks/
3. Ajouter `127.0.0.1 windchill.local` au fichier hosts de la machine cliente
4. `docker compose up -d --build` puis `docker compose logs -f windchill`


host.docker.internal:0.0

mssql:1433;DatabaseName=wind

hostname:port\instance_name;databasename=db_name)