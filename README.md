# mylibrary

App Flutter per la gestione di un **catalogo libri personale**, ispirata a *Handy Library*
ma volutamente più basica.

## Funzionalità

- 🔍 **Ricerca online** per ISBN o titolo: interroga **Google Books**, **OPAC SBN** e
  **Open Library** **in parallelo** e **unisce i risultati** per una scheda più completa
  (priorità Google → SBN → Open Library)
- 🚫 **Nessun duplicato**: inserimento (ricerca/manuale) e import scartano i libri già presenti
  (stesso ISBN, o stesso titolo + autore)
- 📷 **Scansione ISBN** da codice a barre con la fotocamera (Android)
- 📚 **Homepage a griglia di copertine**, con **filtri** per titolo, autore, anno, editore,
  **scaffale** e **stato di lettura**, più ordinamento
- 🗂️ **Scaffali**: cataloga i libri in scaffali, gestiscili (crea/rinomina/elimina) e imposta
  uno **scaffale predefinito** (⭐) applicato automaticamente ai nuovi inserimenti
- 🏷️ **Generi come etichette**: selezione multipla da un elenco estendibile con **categorie personali**
- 🔖 **Stato di lettura**: Da leggere / In lettura / Letto (cambio rapido dal dettaglio,
  badge sulla copertina)
- 📅 **Sessioni di lettura**: date di inizio e fine (anche più letture per le riletture)
- 📈 **Statistiche**: grafici dell'andamento negli anni di **libri** e **pagine** letti
- 🔎 Filtri anche per **genere** e **anno di fine lettura**
- 🖼️ **Copertina personalizzata**: in modifica/inserimento puoi aggiungere o sostituire la
  copertina da **galleria** o **fotocamera**
- 📖 **Dettaglio** del libro al tap sulla copertina (con **sinossi**, **genere** e **recensione**)
- 🔄 **Aggiorna dai dati online**: dal dettaglio, integra i campi mancanti (pagine, sinossi,
  genere, copertina…) dalle fonti, senza sovrascrivere i tuoi dati personali
- 📝 **Recensione personale** per ogni libro (modificabile dal form)
- ✏️ **Aggiunta manuale**, **modifica** ed **eliminazione**
- 💾 **Export/Import** della libreria (con scaffali) su file JSON
- 📊 **Export CSV** di tutti i dati (esclusa l'immagine) — apribile in Excel/Fogli Google
- Dati recuperati: **titolo, autore, editore, anno, copertina, sinossi, genere, numero di pagine**

## Stack

- **Flutter** (Material 3)
- **Hive** (`hive_ce`) per la persistenza locale — funziona su Android **e** Web
- **provider** per lo stato
- **mobile_scanner** per il barcode, **cached_network_image** per le copertine
- **file_saver** / **file_picker** per export/import

## Struttura

```
lib/
  main.dart                      Avvio, tema, provider
  models/book.dart               Modello Book (toMap/fromMap)
  data/book_repository.dart      CRUD su Hive + export/import JSON
  services/book_api_service.dart Ricerca Google Books + fallback Open Library
  providers/library_provider.dart Stato: lista, filtri, ordinamento, CRUD
  screens/                       home, dettaglio, form, ricerca online, scansione
  widgets/                       copertina, pannello filtri
```

## Esecuzione

```bash
flutter pub get

# Web (anteprima rapida sul PC)
flutter run -d chrome

# Android (necessario per la scansione fotocamera)
flutter run -d <device_o_emulatore>
```

Per Android accettare le licenze SDK una tantum:

```bash
flutter doctor --android-licenses
```

## Chiave API Google Books (consigliata)

Google Books senza chiave, su alcune reti/IP condivisi, restituisce **HTTP 429
(quota azzerata)**. Inoltre **Open Library non copre la maggior parte degli ISBN
italiani recenti**: per la ricerca per ISBN dei libri italiani serve quindi Google Books
con una **chiave API gratuita**.

Come ottenerla e impostarla:

1. Vai su [Google Cloud Console](https://console.cloud.google.com/), crea un progetto.
2. Abilita **Books API** (API e servizi → Libreria → "Books API" → Abilita).
3. Crea una **chiave API** (API e servizi → Credenziali → Crea credenziali → Chiave API).
4. Nell'app: menu **⋮ → Impostazioni**, incolla la chiave e salva.

La chiave viene salvata in locale (Hive). Con la chiave impostata la ricerca usa la tua
quota (~1.000 richieste/giorno gratis) e gli ISBN italiani vengono risolti correttamente.

## Note

- La **scansione da fotocamera** è pienamente funzionante su Android; sul Web la ricerca
  manuale per ISBN/titolo resta comunque disponibile.
- **Fallback automatico multi-fonte**: se Google Books fallisce (429) o non trova nulla,
  l'app interroga **OPAC SBN** (Servizio Bibliotecario Nazionale, ottimo per gli ISBN e i
  titoli italiani) e poi **Open Library**. Nota: OPAC SBN non invia header CORS, quindi sul
  **Web** può essere bloccato dal browser; su **Android** funziona regolarmente.
- Se un ISBN non viene trovato online, l'app propone l'**inserimento manuale** con l'ISBN
  già compilato.
- `tool/api_check.dart` è uno script diagnostico: `dart run tool/api_check.dart` verifica
  le ricerche online dalla riga di comando.
