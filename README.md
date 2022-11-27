This repo contains most of the bCASH ecosystem contracts and automated test files used in testing. These contracts have not been audited, and should be used for educational purposes only. 

Deployed contract addresses can be found <a href="docs.butterflycash.lol">here</a>

Special thanks to @bbeldame from Avalant who gave me the testing template when we worked together on the Avalant LP farm. This LP farm was the basis for the bCASH LP farm, and all tests in this repo use the same testing template.

```yarn test``` to launch test, you can also only trigger test for a particular file if you want (you should)

```yarn``` to install all dependencies

```cp .env.example .env``` and adapt the .env, you only need the PRIVATE_KEY. make a burner wallet for this, just in case you commit by mistake but .env is in the .gitignore
