Want to add 3DS jingles to this repo, but don't know how? It's really simple!

Fork the repository and we'll get started.

First, get your 3DS rom files ready. This means they'll need to be in either the .3ds or .cci file format. If you have .zcci, .z3ds, .cia, or .app, you will have to convert them into one of these two formats.

Then, you're going to need to download the tools [3dstool](https://github.com/dnasdw/3dstool) and [vgmstream](https://github.com/vgmstream/vgmstream-releases/releases/download/nightly/vgmstream-win64.zip). Depending on the rom, I would highly recommend you have `python3`, and on Windows, python is required.

Once you have these installed, move all your ROMs into one folder. For ease of use, scripts are provided to extract your .wavs for you. (`extract_jingle.sh/bat` in the Contributing/n3ds directory of the repository.) Thank you to Celthium for providing the batchfile.

Then, move your jingles into `jingles/n3ds`, and edit the `index.json` in the root of the repository accordingly, adding a new entry in the json with this format:

```
    { "game": "*game name as it appears in Cocoon*", "file": "jingles/n3ds/*your jingle here*.wav"},
```

For example,

```
    {"game": "Animal Crossing - New Leaf", "file": "jingles/n3ds/animal-crossing-new-leaf.wav"},
```

Please sort the games in alphabetical order.

Once that's done, open a pull request, and you're done!

Don't know how to make a pull request, but still want to add jingles? Contact me on Discord at `red6785`! I'll probably accept!
