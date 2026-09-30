/// Hírarchívum: modellek, forráslista, feldolgozók, SQLite-tár és
/// repository. A korábbi egyetlen `news.dart` helyett a `news/` mappa
/// fájljai; ez a barrel változatlanul tartja a meglévő importokat.
library;

export 'package:courtboard/data/news/news_models.dart';
export 'package:courtboard/data/news/news_parsers.dart';
export 'package:courtboard/data/news/news_repository.dart';
export 'package:courtboard/data/news/news_sources.dart';
export 'package:courtboard/data/news/news_store.dart';
