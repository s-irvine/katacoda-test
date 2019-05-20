Signing your images allows you to cryptographically verify the content of that image. You can use tools such as Portieris, which we'll cover later in this tutorial, to check image signatures at deploy time, to ensure that you trust the code that's running in your production environments. Some tools, including Harbor and Docker, refer to this feature as Content Trust.

Notary is a tool that manages signatures. It implements The Update Framework (TUF), a specification for securing application deployment. Both Notary and TUF are "Incubating" CNCF projects.

Using Notary, you can digitally sign and then verify the content of your container images at deploy time via their digest. Notary is typically integrated alongside a Container Registry to provide this functionality. In this tutorial, we use Harbor as both the Container Registry and the Notary server.

## Configure Harbor

1. Open the Harbor UI.
1. Select the library project, and then click the Configuration tab.
1. Select `Enable content trust`
1. Click `Save`

## Signing images

When you enable Content Trust, Docker pushes trust information into Notary when you push your image.

1. Enable Docker Content Trust.

    ```bash
    export DOCKER_CONTENT_TRUST=1
    export DOCKER_CONTENT_TRUST_SERVER=https://127.0.0.1:30004
    ```{{execute}}

2. Push an image to Harbor. Your image will push as normal, but afterwards you'll be prompted to create passphrases for two signing keys:
    - Your root key, which is used to initialize repositories.
    - Your repository key, which is used to sign the image content.

    Make sure to set these passphrases to something that you remember, because you'll need to refer back to them. In this demo they can be the same thing, but in production it's safer to use different passphrases for each key.

    ```bash
    docker tag 127.0.0.1:30002/library/demo-api:secure 127.0.0.1:30002/library/demo-api:signed
    docker push 127.0.0.1:30002/library/demo-api:signed
    ```{{execute}}

3. Check your image signature.

    ```bash
    docker trust inspect --pretty 127.0.0.1:30002/library/demo-api:signed
    ```{{execute}}

## Verifiable trust

You've signed the image already using the repository key, but this key doesn't prove your identity. The repository key is also unique to that image repository, so you'll create different keys for each image repository that you sign. Notary lets the repository key holder add other people's key pairs so that they can sign the image, and users can use those people's public key to verify their signatures.

1. Create a signing key called `portierisdemo`.

    ```bash
    docker trust key generate portierisdemo
    ```{{execute}}

    The private key goes in to your Docker Content Trust directory. The public key is saved to `portierisdemo.pub` in your working directory.

2. Add your key as a signer in Notary.

    ```bash
    docker trust signer add --key=portierisdemo.pub portierisdemo 127.0.0.1:30002/library/demo-api:signed
    ```{{execute}}

3. TODO push the image again and show that it prompts for the portierisdemo key, then inspect again

4. Let's look at the image that we pushed with content trust turned off, for comparison.

    ```bash
    docker trust inspect --pretty 127.0.0.1:30002/library/demo-api:secure
    ```{{execute}}

    This image wasn't signed when we pushed it, so we get a message saying that there's no trust information:

    ```bash
    No signatures or cannot access 127.0.0.1:30002/library/demo-api:secure
    ```

5. To see the trust files stored on disk, examine the local `~/.docker/trust` directory:

    TODO install tree

    ```bash
    tree ~/.docker/trust
    ```{{execute}}

    Notary caches signatures locally so that you don't need to go to the server each time. Cached signature data is stored in `~/.docker/trust/tuf` in folders representing the image name.

    Signing keys are stored in `~/.docker/trust/private`. If you've pulled trust information from a repository before, Notary caches the repository key and verifies that the same repository key is still being used. If the repository key reported by the server is different to the one that Notary saw before, the pull is rejected because the information in the server might have been changed by a third party.

TODO move "Configure notary" down here. Then add section about deploying. Harbor blocks if "Enable content trust" is on and the latest image is unsigned.
