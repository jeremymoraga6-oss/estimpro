# Signature Android — clé permanente

## Pourquoi

Jusqu'ici, `android/app/build.gradle.kts` signait la build *release* avec la clé
de **debug** :

```kotlin
release {
    signingConfig = signingConfigs.getByName("debug")
}
```

Cette clé n'est pas versionnée : Android la génère automatiquement quand elle est
absente, avec une paire de clés **aléatoire**. Chaque runner GitHub Actions étant
neuf, **chaque build produisait un APK signé différemment**.

Conséquence : Android refuse d'installer une mise à jour dont la signature diffère
(`INSTALL_FAILED_UPDATE_INCOMPATIBLE`, affiché « Application non installée »). La
seule issue était de désinstaller — ce qui efface le stockage privé de l'app,
donc **toutes les estimations**.

Avec une clé permanente, l'empreinte reste identique d'une release à l'autre et
les mises à jour s'installent normalement, en conservant les données.

---

## 1. Générer la clé (une seule fois)

Le Mac n'a pas de Java installé, donc pas de `keytool` utilisable. On passe par
`openssl`, présent d'origine, qui produit un magasin **PKCS12** — le format
moderne, accepté tel quel par Gradle (`storeType = PKCS12`).

**Étape A** — créer la clé privée et son certificat, valable 27 ans :

```bash
openssl req -x509 -newkey rsa:2048 -sha256 -days 10000 -nodes \
  -keyout /tmp/estimpro.key -out /tmp/estimpro.crt \
  -subj "/CN=Jeremy Moraga/O=Faucigny Immobilier/C=FR"
```

**Étape B** — empaqueter dans le magasin, sous l'alias `estimpro` :

```bash
openssl pkcs12 -export \
  -inkey /tmp/estimpro.key -in /tmp/estimpro.crt \
  -name estimpro -out ~/estimpro-upload-key.p12
```

Un mot de passe est demandé deux fois (saisie puis confirmation). **Retenez-le** :
c'est celui à déclarer en secret GitHub. En PKCS12 le mot de passe du magasin et
celui de la clé sont le même — les deux secrets recevront donc la même valeur.

**Étape C** — effacer les fichiers intermédiaires, qui contiennent la clé
privée en clair :

```bash
rm -f /tmp/estimpro.key /tmp/estimpro.crt
```

> ⚠️ **Sauvegarde le fichier `.p12` et son mot de passe hors du dépôt**
> (gestionnaire de mots de passe, disque chiffré). En cas de perte, il devient
> impossible de publier une mise à jour installable : il faudrait à nouveau
> désinstaller l'app, donc reperdre les données. Le `.gitignore` empêche
> volontairement de le committer.

---

## 2. Déclarer les secrets GitHub

Encoder le keystore sur une seule ligne :

```bash
base64 -i ~/estimpro-upload-key.p12 | tr -d '\n' | pbcopy
```

Puis dans **Settings → Secrets and variables → Actions**, créer quatre secrets :

| Secret | Valeur |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | le contenu collé depuis `pbcopy` |
| `ANDROID_STORE_PASSWORD` | le mot de passe choisi a l'etape B |
| `ANDROID_KEY_PASSWORD` | le meme mot de passe (format PKCS12) |
| `ANDROID_KEY_ALIAS` | `estimpro` |

Le workflow échoue désormais explicitement si `ANDROID_KEYSTORE_BASE64` est
absent, plutôt que de produire un APK non installable.

---

## 3. Builds release locales (facultatif)

Pour signer aussi depuis le Mac, créer `android/key.properties` (déjà ignoré par
git) :

```properties
storeFile=/Users/moraga/estimpro-upload-key.p12
storeType=PKCS12
storePassword=…
keyPassword=…
keyAlias=estimpro
```

Sans ce fichier, la build locale retombe sur la clé de debug et affiche un
avertissement encadré dans la sortie Gradle.

---

## 4. Vérifier

Chaque build CI affiche l'empreinte du certificat :

```
Empreinte du certificat de signature
  SHA-256 digest: 3A:7B:…
```

Cette valeur doit être **identique d'une release à l'autre**. Si elle change,
les mises à jour seront de nouveau refusées.

---

## 5. ⚠️ La bascule fait perdre les données du téléphone

L'APK actuellement installé est signé avec une clé de debug aléatoire. Le premier
APK correctement signé **ne pourra donc pas s'installer par-dessus** : il faudra
désinstaller une dernière fois, ce qui efface les estimations présentes sur
l'appareil.

Cette désinstallation est la dernière : toutes les mises à jour suivantes
s'installeront normalement.

**Avant de désinstaller**, exporter ce qui doit être conservé.

L'APK installé aujourd'hui est antérieur à l'ajout du bouton de sauvegarde : le
seul export disponible dessus est celui de la section 7, **estimation par
estimation** (`Exporter le dossier` → ZIP / e-mail).

À partir de la version signée, l'écran Profil offre un export global
(estimations, base locale et réglages dans un seul zip) et une restauration qui
fusionne sans écraser. C'est ce qu'il faudra utiliser pour toutes les
sauvegardes suivantes.

## Ordre recommandé

1. Exporter les dossiers importants depuis la section 7 de l'app actuelle.
2. Créer la clé et déclarer les quatre secrets (étapes 1 et 2).
3. Laisser la CI produire un APK signé.
4. Désinstaller, puis installer cet APK — **la dernière désinstallation**.
5. Vérifier que l'export global du Profil fonctionne, et le prendre en habitude.
