const fs = require('fs');
const path = require('path');

const renames = [
  { old: '999-social-credit-siren.mp3', new: 'social_credit.mp3', title: 'SOCIAL CREDIT' },
  { old: 'aayein-meme.mp3', new: 'aayein.mp3', title: 'AAYEIN?!' },
  { old: 'among-us-role-reveal-sound.mp3', new: 'among_us.mp3', title: 'AMONG US' },
  { old: 'anime-wow-sound-effect-mp3cut.mp3', new: 'anime_wow.mp3', title: 'ANIME WOW' },
  { old: 'bing-chilling_fcdGgUc.mp3', new: 'bing_chilling.mp3', title: 'BING CHILLING' },
  { old: 'dexter-meme.mp3', new: 'dexter_surprise.mp3', title: 'SURPRISE MF' },
  { old: 'directed-by-robert-b_voI2Z4T.mp3', new: 'directed_by_robert.mp3', title: 'DIRECTED BY ROBERT' },
  { old: 'dun-dun-dun-sound-effect-brass_8nFBccR.mp3', new: 'dun_dun_dun.mp3', title: 'DUN DUN DUN!' },
  { old: 'emotional-damage-meme.mp3', new: 'emotional_damage.mp3', title: 'EMOTIONAL DAMAGE' },
  { old: 'error_CDOxCYm.mp3', new: 'windows_error.mp3', title: 'WINDOWS ERROR' },
  { old: 'faaah.mp3', new: 'faaaah.mp3', title: 'FAAAAH' },
  { old: 'fbi-open-up_dwLhIFf.mp3', new: 'fbi_open_up.mp3', title: 'FBI OPEN UP!' },
  { old: 'huh_37bAoRo.mp3', new: 'huh.mp3', title: 'HUH?!' },
  { old: 'jojos-bizarre-adventure-ay-ay-ay-ay-_-sound-effect.mp3', new: 'jojo_pillar_men.mp3', title: 'JOJO AYAYAY' },
  { old: 'keyboard-meme.mp3', new: 'rage_keyboard.mp3', title: 'RAGE KEYBOARD' },
  { old: 'meme-de-creditos-finales.mp3', new: 'curb_credits.mp3', title: 'FINAL CREDITS' },
  { old: 'meme_lgkJmX6.mp3', new: 'bonk_meme.mp3', title: 'BONK!' },
  { old: 'meri-jung-emotional.mp3', new: 'meri_jung.mp3', title: 'MERI JUNG' },
  { old: 'movie_1_C2K5NH0.mp3', new: 'run_meme.mp3', title: 'RUN!' },
  { old: 'nani-meme-sound-effect.mp3', new: 'omae_wa_nani.mp3', title: 'OMAE WA NANI' },
  { old: 'no-no-wait-wait.mp3', new: 'wait_wait_wait.mp3', title: 'WAIT WAIT WAIT!' },
  { old: 'oh-my-god-meme.mp3', new: 'oh_my_god.mp3', title: 'OH MY GOD' },
  { old: 'spiderman-meme-song.mp3', new: 'spiderman_meme.mp3', title: 'SPIDERMAN' },
  { old: 'subway-surfers-bass-boosted.mp3', new: 'subway_surfers_bass.mp3', title: 'SUBWAY SURFERS' },
  { old: 'tf_nemesis.mp3', new: 'tf2_nemesis.mp3', title: 'TF2 NEMESIS' },
  { old: 'the-lion-sleeps-tonight.mp3', new: 'lion_sleeps_tonight.mp3', title: 'A-WIMOWEH' },
  { old: 'vine-boom-sound-effect_KT89XIq.mp3', new: 'vine_boom.mp3', title: 'VINE BOOM' },
  { old: 'zvuk-fotoapparata.mp3', new: 'camera_snap.mp3', title: 'CAMERA SNAP 📸' },
];

const duplicates = ['emotional-damage_svaNMfN.mp3', 'meme-de-creditos-finales_qHtIjyQ.mp3'];

const dirs = [
  path.join(__dirname, '..', 'sounds'),
  path.join(__dirname, '..', 'mobile', 'assets', 'sounds'),
];

for (const dir of dirs) {
  for (const dup of duplicates) {
    const p = path.join(dir, dup);
    if (fs.existsSync(p)) fs.unlinkSync(p);
  }

  for (const item of renames) {
    const oldP = path.join(dir, item.old);
    const newP = path.join(dir, item.new);
    if (fs.existsSync(oldP)) {
      fs.renameSync(oldP, newP);
    }
  }
}

console.log('Renamed all sounds cleanly!');
