/// Hírarchívum: modellek, forráslista, feldolgozók, SQLite-tár és
/// repository. A korábbi egyetlen `news.dart` helyett a `news/` mappa
/// fájljai; ez a barrel változatlanul tartja a meglévő importokat.
library;

export 'news/news_models.dart';
export 'news/news_parsers.dart';
export 'news/news_repository.dart';
export 'news/news_sources.dart';
export 'news/news_store.dart';
