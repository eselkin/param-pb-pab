# Plutus Platform starter project

This project gives a simple starter project for using the Plutus Platform.

## Setting up

### VSCode devcontainer

Use the provided VSCode devcontainer to get an environment with the correct tools set up.

- Install Docker
- Install VSCode
  - Install the [Remote Development extension pack](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack)
  - You do *not* need to install the Haskell extension
- Ensure you have a `~/.cabal/packages` folder. You can create this via `mkdir -p ~/.cabal/packages`; it's used to cache cabal packages.
- Clone this repository and open it in VSCode
  - It will ask if you want to open it in the container, say yes.
  - The first time it will take a few minutes to download the devcontainer image from dockerhub,
  - `cabal build` from the terminal should work (unless you didn't have a `~/.cabal` folder, in which case you'll need to run `cabal update` first.)
  - Opening a Haskell file should give you IDE features (it takes a little while to set up the first time)

Note: This uses the [plutus-starter-devcontainer image on dockerhub](https://hub.docker.com/r/inputoutput/plutus-starter-devcontainer), if
you wish to build the image yourself, you can do so as follows:
  - Clone https://github.com/input-output-hk/plutus,
  - Set up your machine to build things with Nix, following the [Plutus README](https://github.com/input-output-hk/plutus/blob/master/README.adoc) (make sure to set up the binary cache!),
  - Build and load the docker container: `docker load < $(nix-build default.nix -A devcontainer)`,
  - Adjust the `.devcontainer/devcontainer.json` file to point to your local image.

### Cabal+Nix build

Alternatively, use the Cabal+Nix build if you want to develop with incremental builds, but also have it automatically download all dependencies.

Set up your machine to build things with `Nix`, following the [Plutus README](https://github.com/input-output-hk/plutus/blob/master/README.adoc) (make sure to set up the binary cache!).

To enter a development environment, simply open a terminal on the project's root and use `nix-shell` to get a bash shell:

```
$ nix-shell
```

Otherwise, you can use [direnv](https://github.com/direnv/direnv) which allows you to use your preferred shell. Once installed, just run:

```
$ echo "use nix" > .envrc # Or manually add "use nix" in .envrc if you already have one
$ direnv allow
```

and you'll have a working development environment for now and the future whenever you enter this directory.

The build should not take too long if you correctly set up the binary cache. If it starts building GHC, stop and setup the binary cache.

Afterwards, the command `cabal build` from the terminal should work (if `cabal` couldn't resolve the dependencies, run `cabal update` and then `cabal build`).

Also included in the environment is a working [Haskell Language Server](https://github.com/haskell/haskell-language-server) you can integrate with your editor.
See [here](https://github.com/haskell/haskell-language-server#configuring-your-editor) for instructions.

## The Modified Plutus Application Backend (PAB) example - Parameterised Piggy Bank

For this example, it is easiest to use the `Parameterised Piggy Bank.postman_collection.json`
You can refer to the Postman code to acquire the curl patterns to achieve the same result (but with more manual labor).

---
**Also, [here](https://youtu.be/deUxZvxzNPA)'s a video of me describing the steps and what this contract does differently.**

---


1. Build the PAB executable:

```
cabal build -- ppb
```

2. Run the PAB binary:

```
cabal exec -- ppb
````

This will then start up the server on port 9080. The devcontainer process will then automatically expose this port so that you can connect to it from any terminal (it doesn't have to be a terminal running in the devcontainer).

First, let's verify that the game is present in the server (you should probably still do this with curl, because it's easy):

3. Check what contracts are present:

```
curl -s http://localhost:9080/api/contract/definitions | jq
```

You should receive a list of contracts and the endpoints that can be called on them, and the arguments
required for those endpoints.

We're interested in the `ParameterisedPiggyBankSchema`
#### To be able to add money to a piggy bank you need wallets with ADA

1. We can make any number of wallets, but the first three requests in the Parameterised Piggy Bank Workspace in Postman create wallets. Execute them by clicking send on each successively. Try not to hit send twice on an endpoint, because there's not much protection for this step.

2. Start the contract instances (we're going to make 3, one for each wallet). So click send on each of those requests as well

3. Now we'll put 1.000.000 Lovelace into the piggy bank that is parameterised by Wallet 3's public key hash using the instance from Wallet 1 (The next postman request).

4. Now we'll do another put of the same amount to the same piggy bank script address using the instance from Wallet 2.

5. We can test this worked by the next postman request which inspects (using and endpoint of the same name) the piggy bank parameterized by wallet 3's PKH using Wallet 2's instance. The postman request does not return anything (yet... we're still working on that). But you can go to your terminal where you're running the ppb and examine the logs and see that the inspect indeed says there's 2million lovelace at that script address

6. Now we can leave the money there (wait! who does that!). Wallet 3 wants all the Lovelace! So she empties is using the empty endpoint in the next Postman request.

7. Finally you can examine the final balances by exiting the PAB with `enter`


Finally, also node that the PAB also exposes a websocket, which you can read about in
the general [PAB Architecture documentation](https://github.com/input-output-hk/plutus/blob/master/plutus-pab/ARCHITECTURE.adoc).


## Support/Issues/Community

If you're looking for support, or would simply like to report a bug, feature
request, etc please do so over on the main [plutus
repository](https://github.com/input-output-hk/plutus).

For more interactive discussion, you can join the [IOG Technical Community
Discord](https://discord.gg/sSF5gmDBYg).

Thanks!
