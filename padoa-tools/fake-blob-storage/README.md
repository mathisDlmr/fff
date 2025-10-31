# Fake Blob Storage

Ce repository propose une application Javascript permettant d'émuler en local le Blob Storage d'Azure.
Son fonctionnement est basé sur le module Azurite (https://www.npmjs.com/package/azurite).

## Lancer le projet

Le projet ne dispose que de 2 commandes :

- ``npm run yarn`` permet d'installer les dépendances de l'application.

- ``npm run start`` permet de lancer l'application.

Les variables d'environnement suivantes sont disponibles :

- ``BLOB_ENDPOINT`` permet de définir le endpoint sur lequel se lance Azurite.

- ``BLOB_PORT`` permet de définir le port sur lequel se lance Azurite.

- ``BLOB_CONTAINER_NAMES`` permet de définir les noms des containers qui seront créés par le Fake Blob Storage.
Il est possible de créer plusieurs containers en séparant leur nom par une virgule 
(exemple: ``BLOB_CONTAINER_NAMES=fake-media-local,fake-medical-local-e2e``).

Le projet utilise obligatoirement les credentials par défaut d'Azurite : 

- Account Name : ``devstoreaccount1``

- Shared Key : ``Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==``

Pour se connecter au projet, on peut utiliser la string de connection suivante : 

``DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://fake-blob-storage:10000/devstoreaccount1``

## Images Docker

L'image du service est poussé sur plusieurs Registry Docker. L'image est disponible sur :

- ACR : ``padoa.azurecr.io/padoa-tools/fake-blob-storage:main``

- ECR : ``096108736502.dkr.ecr.eu-west-1.amazonaws.com/padoa-tools/fake-blob-storage:main``
