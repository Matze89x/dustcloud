# Audio Generator for Xiaomi Vacuum Generation 1 & Generation 2

# Author: Dennis Giese [dennis@dontvacuum.me]
# Copyright 2017 by Dennis Giese

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

It is possible to create new language files which can be integrated into the rooted firmware. To generate the language files you can use the `generate_audio.py` script in this folder.

It will read the content auf audio_xx.csv (whereby xx is a country language code like de_de or en_US) and use one of the supported engines to generate mp3 files for inclusion in the firmware. The language codes are the [ISO-639-1](https://en.wikipedia.org/wiki/ISO_639-1) format, so that the engine can use a voice with suitable pronounciation.

You'll notice that each engine has its problems with mixed langauges (e.g. german with english words in it). A little testing is necessary to find a suitable pronunciation.


# Requirements
1. python3
1. [pipenv](https://github.com/pypa/pipenv) Install using: `pip install pipenv`
1. ffmpeg (to convert generated files into wav)

# Installation
You can either install the python3 requirements manually or you install and use them with pipenv:

* install ffmpeg
* change to root folder of repository (where is placed Pipfile) and run:
* `pipenv install`
* `pipenv shell`
* `cd devices/xiaomi.vacuum/audio_generator`
* start script with `./generate_audio.py` program ask for your language selection

# Supported engines
## gtts (Google Text To Speech)
* https://github.com/pndurette/gTTS
## espeak (eSpeak NG Text-to-Speech)
* https://github.com/espeak-ng/espeak-ng
## macos (Mac OS X integrated Text To Speech)
* https://developer.apple.com/legacy/library/documentation/Darwin/Reference/ManPages/man1/say.1.html
* You may specify a voice directly after the say command in the documentation. You can get a complete list from the command `say -v ?`. If you do not specify a different voice with `-v VoiceName` Mac OS will use your current system language
## aws (Amazon Polly)
* https://docs.aws.amazon.com/polly/latest/dg/what-is.html
