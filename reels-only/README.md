# Local Instagram controls — v2

The new behavior preserves native data and loading for individually selected Reels,
including videos opened from messages or profiles and the account's own posts.
It blocks scrolling in `IGUnifiedVideoCollectionView` and disables the existing
Instagram auto-scroll switch. With the Reels restriction enabled, the Reels tab
and suggested Reels carousel are also hidden.

Hold three fingers on the screen for one second to open **Bloqueos de Instagram**.
The three independent controls are:

- **Bloquear scroll de Reels**: on by default.
- **Ocultar feed del inicio**: off by default; preserves the story tray and the
  known post-creation entry while hiding the other home-feed data objects.
- **Ocultar historias del inicio**: off by default; hides home story trays,
  including suggested stories. Stories reached directly through profiles are
  not blocked.

Fully close and reopen the app after changing settings. Preferences remain in
the application's local defaults. No account, purchase, subscription, network,
keychain, downloading, or analytics code is added by this blocker. Instagram Plus
eligibility and purchases are left entirely to Instagram.

The selectors originate in SCInsta and were confirmed in Instagram 418.2.0 for
v1. A newer Instagram IPA must be checked for compatible methods and tested on a
device before claiming this v2 works there. Mock tests validate our behavior,
not Instagram's private interfaces, every navigation route, or subscription
compatibility. A source-only build is not an installable IPA or an antivirus scan.

Do not overwrite the pinned v1 build artifact. Prefer a newer, unmodified
decrypted base with verifiable provenance. The available 451.0.0 candidate was
already modified with RyukGram; it is not an authenticated original base.

`package_review_candidate.py` creates an **experimental, unsigned review IPA**
from that exact hash. It removes RyukGram and its bundle, removes its
CydiaSubstrate framework, replaces its sideload helper with the pinned helper
from v1, and adds our v2 blocker. File sharing is disabled. Every other file is
checked byte-for-byte against that candidate. The main binary changes only in
the load-command/header area; its code and data remain unchanged. This proves
the scope of our edits, not the authenticity or safety of the source. The old
signature is invalid after these edits and must be replaced by the installer.

Scan the resulting IPA and the changed executable separately before considering
installation. This candidate has not been tested on an iPhone; successful builds,
mock tests, symbol-string presence and antivirus scans do not prove runtime
compatibility, subscription availability, or absence of malware.
