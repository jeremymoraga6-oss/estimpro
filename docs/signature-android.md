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

```bash
keytool -genkey -v \
  -keystore ~/estimpro-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias estimpro
```

`keytool` demande un mot de passe puis quelques informations d'identité (nom,
organisation, pays). Le mot de passe du magasin et celui de la clé peuvent être
identiques.

> ⚠️ **Sauvegarde ce fichier `.jks` et son mot de passe hors du dépôt**
> (gestionnaire de mots de passe, disque chiffré). En cas de perte, il devient
> impossible de publier une mise à jour installable : il faudrait à nouveau
> désinstaller l'app, donc reperdre les données. Le `.gitignore` empêche
> volontairement de le committer.

---

## 2. Déclarer les secrets GitHub

Encoder le keystore sur une seule ligne :

```bash
base64 -i ~/estimpro-upload-key.jks | tr -d '\n' | pbcopy
```

Puis dans **Settings → Secrets and variables → Actions**, créer quatre secrets :

| Secret | Valeur |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | le contenu collé depuis `pbcopy` |
| `ANDROID_STORE_PASSWORD` | mot de passe du magasin |
| `ANDROID_KEY_PASSWORD` | mot de passe de la clé |
| `ANDROID_KEY_ALIAS` | `estimpro` |

Le workflow échoue désormais explicitement si `ANDROID_KEYSTORE_BASE64` est
absent, plutôt que de produire un APK non installable.

---

## 3. Builds release locales (facultatif)

Pour signer aussi depuis le Mac, créer `android/key.properties` (déjà ignoré par
git) :

```properties
storeFile=/Users/moraga/estimpro-upload-key.jks
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

**Avant de désinstaller**, exporter ce qui doit être conservé. Le seul export
disponible aujourd'hui est celui de la section 7, **estimation par estimation**
(`Exporter le dossier` → ZIP / e-mail).

`lib/services/backup_service.dart` implémente pourtant un export global
(`exportBackup()` / `importBackup()`) mais **n'est branché à aucun écran** — il
est donc inutilisable en l'état. Le câbler dans l'écran Profil avant la bascule
rendrait la migration bien plus sûre.
