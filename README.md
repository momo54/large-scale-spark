# Projet PySpark minimal

Ce petit projet fournit un exemple simple PySpark avec un notebook Jupyter et un script exécutable.

Contenu créé :
- `notebooks/analysis.ipynb` : notebook interactif (lecture des données, agrégation, affichage + graphique)
- `src/run_sample.py` : script Python pour exécuter la même transformation en CLI
- `data/sample.csv` : petit jeu de données d'exemple
- `requirements.txt` : dépendances Python
- `.gitignore`

Pré-requis
- Python 3.8+
- Java 11+ (nécessaire pour PySpark)
- (Optionnel) Environnement virtuel recommandé

Installation rapide (zsh) :

```bash
python -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

Exécuter le script CLI :

```bash
python src/run_sample.py
```


Lancer le notebook :

```bash
jupyter notebook notebooks/intro.ipynb
```


Notes
- Si tu rencontres des erreurs liées à Java, vérifie que `JAVA_HOME` est correctement défini et que `java -version` renvoie une version 11+.
- PySpark installe une version de Spark locale via pip, mais si tu as une installation Spark locale préférée, tu peux l'utiliser également.

Cluster Docker local (mode cluster)
----------------------------------

Un docker-compose est fourni pour simuler un petit cluster Spark (1 master + 3 workers) et un service Jupyter connecté, basés sur les images officielles Apache Spark (Spark 4.0.0, Java 21, Python 3) :

- `docker-compose.yml` : services `spark-master`, `spark-worker-1..3`, `jupyter` (Jupyter est construit sur l'image officielle Spark pour aligner les versions Java/Spark/PySpark).
- `docker/run_cluster.sh` et `docker/stop_cluster.sh` : scripts helpers pour démarrer/arrêter.

Volumes partagés dans les conteneurs
- `/data` (lecture seule) monte ce repo dans tous les conteneurs. Le notebook lit donc ses données via `/data/...` en mode cluster.
- `/shared` (lecture/écriture) monte `./output` du host dans tous les conteneurs. Les jobs Spark peuvent y écrire des résultats visibles côté host dans `output/`.

Démarrage (depuis la racine du projet) :
- Lance le cluster avec le script fourni. Le service Jupyter sera accessible sans token sur http://localhost:8888 et le Spark Master UI sur http://localhost:8080.
- Si tu modifies `docker-compose.yml`, relance le cluster pour prendre en compte les volumes/paramètres.

Démarrer/arrêter uniquement Jupyter
-----------------------------------

Quand le cluster est déjà créé, tu peux contrôler seulement le service Jupyter:

- Démarrer/arrêter avec docker compose (recommandé):

```bash
docker compose start jupyter
docker compose stop jupyter
```

- Démarrer/arrêter le conteneur existant directement avec docker (si déjà créé par compose):

```bash
docker start jupyter
docker stop jupyter
```

- Lancer Jupyter pour la première fois (ou après suppression) et le créer si besoin:

```bash
docker compose up -d jupyter
```

- Voir les logs de Jupyter:

```bash
docker logs -f jupyter
```

Note: si tu changes l'image ou le Dockerfile de Jupyter (`docker/jupyter/Dockerfile`), reconstruis avant de redémarrer:

```bash
docker compose build jupyter && docker compose up -d jupyter
```

Utilisation du notebook en mode cluster
- Le notebook `notebooks/analysis.ipynb` détecte automatiquement le mode cluster via `SPARK_MASTER` (défini dans `docker-compose.yml`).
- En mode cluster, il lit les fichiers depuis `/data` (par exemple `/data/sample.csv`, `/data/edges.csv`) et écrit les sorties dans `/shared` (côté host: `./output`).
- En mode local (sans Docker), il lit et écrit directement dans `data/` et `output/` du repo.
- Pour le volet PageRank (RDD + map-side join), le notebook partitionne/persist les RDD pour faciliter le map-side join et affiche un diagnostic de shuffles.

Arrêt du cluster : utilise `docker/stop_cluster.sh`.

Sécurité
- Jupyter démarre sans token pour simplifier les essais locaux. Ne l'expose pas sur un réseau public.

Vérifier le cluster sans Jupyter (spark-submit)
-----------------------------------------------

Un petit job de vérification est fourni: `src/verify_cluster.py`.
- Il lit `sample.csv` et `edges.csv` depuis le volume `/data` (dans les conteneurs: `/data/data/...`).
- Il écrit les résultats dans `/shared/verify_cluster_out` (côté host: `output/verify_cluster_out`).

Exécuter le job via un conteneur éphémère relié au réseau du cluster:

```bash
docker run --rm \
	--network large-scale-spark_default \
	-v "$(pwd)":/work \
	-v "$(pwd)"/output:/shared \
	-v "$(pwd)":/data:ro \
	-w /work \
	spark:4.0.0-java21-python3 \
	/opt/spark/bin/spark-submit --master spark://spark-master:7077 /work/src/verify_cluster.py
```

Attendus en sortie (extrait):
- Spark master: spark://spark-master:7077
- RDD sum result: 999000
- Rows in sample: 8
- Edges count (no header): 8
- Wrote results to: /shared/verify_cluster_out

Tu peux ensuite lister la sortie côté host:

```bash
ls -la output/verify_cluster_out
```

Soumettre le WordCount (script fourni)
-------------------------------------

Un petit job WordCount est fourni en `src/wordcount.py` (prêt pour `spark-submit`). Pour simplifier la soumission vers le cluster Docker local, un helper shell est disponible : `bin/submit_wordcount.sh`.

Usage simple (depuis la racine du projet) :

```bash
./bin/submit_wordcount.sh
```

Par défaut le script utilise :
- input : `/data/data/mobydick.txt` (contenu attendu dans `data/` du repo — accessible dans les conteneurs via `/data`)
- output : `/shared/mobydick_wc` (côté host : `./output/mobydick_wc`)

Tu peux préciser manuellement input et output (chemins vus par le conteneur) :

```bash
./bin/submit_wordcount.sh /data/data/mobydick.txt /shared/mobydick_wc
```

Le script lance un conteneur éphémère basé sur l'image Spark du compose et exécute :

```
/opt/spark/bin/spark-submit --master spark://spark-master:7077 /work/src/wordcount.py <input> <output>
```

Après réussite tu trouveras un dossier CSV dans `./output/mobydick_wc` (un seul fichier CSV coalescé avec en-tête `word,count`).

Si tu préfères lancer manuellement sans le helper, voici l'équivalent `docker run` :

```bash
docker run --rm \
	--network "${PWD##*/}_default" \
	-v "$(pwd)":/work \
	-v "$(pwd)"/output:/shared \
	-v "$(pwd)":/data:ro \
	-w /work \
	spark:4.0.0-java21-python3 \
	/opt/spark/bin/spark-submit --master spark://spark-master:7077 /work/src/wordcount.py /data/data/mobydick.txt /shared/mobydick_wc
```

Conseils :
- Rends le helper exécutable si besoin : `chmod +x bin/submit_wordcount.sh`.
- Vérifie l'UI du Master et les logs pour suivre la progression du job.


REPL PySpark interactif (sans Jupyter)
--------------------------------------

Option A — Dans le conteneur master (simple):

```bash
docker exec -it spark-master bash -lc 'HOME=/home/spark PYSPARK_PYTHON=python3 /opt/spark/bin/pyspark --master spark://spark-master:7077'
```

Dans le REPL PySpark:

```python
sc = spark.sparkContext
sc.setLogLevel("WARN")
rdd1=sc.parallelize(range(100))
print(rdd1.count())
rdd2=rdd1.filter(lambda x: x<50)
print(rdd2.count())

# Lecture depuis le volume partagé (RO)
df = spark.read.option("header", True).csv("/data/data/sample.csv")
df.show()

# Écriture vers le volume partagé (RW)
(df.groupBy("department").count()
	 .coalesce(1)
	 .write.mode("overwrite").option("header", True)
	 .csv("/shared/pyspark_out"))
```

Option B — Conteneur éphémère (isole le driver):

```bash
docker run --rm -it \
	--network large-scale-spark_default \
	-v "$(pwd)":/data:ro \
	-v "$(pwd)"/output:/shared \
	spark:4.0.0-java21-python3 \
	bash -lc 'PYSPARK_PYTHON=python3 /opt/spark/bin/pyspark --master spark://spark-master:7077'
```

REPL Scala (spark-shell)
------------------------

Le shell Scala est pratique pour de courts tests. Attention: jline veut écrire l'historique sous `$HOME`.

1) Créer le répertoire HOME si nécessaire (une seule fois):

```bash
docker exec -u 0 -it spark-master bash -lc "mkdir -p /home/spark && chown -R spark:spark /home/spark"
```

2) Lancer spark-shell avec un HOME inscriptible:

```bash
docker exec -it spark-master bash -lc 'HOME=/home/spark /opt/spark/bin/spark-shell --master spark://spark-master:7077'
```

Dans le shell Scala:

```scala
// Syntaxe correcte (sc.range(start, end))
sc.range(0, 10).sum   // => 45
spark.range(10).count // => 10
```

Rappels chemins (mode cluster)
------------------------------

- Lecture: `/data/data/...` (car `/data` pointe sur la racine du repo dans les conteneurs)
- Écriture: `/shared/...` (côté host: `./output`)
