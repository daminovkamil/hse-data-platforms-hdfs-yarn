# HDFS и YARN — домашние задания №1–2

Скрипты рассчитаны на четыре VM с Ubuntu 24.04, Java 11 и Hadoop 3.4.1.
Сначала разворачивается HDFS, затем YARN.

| Узел | Демоны |
| --- | --- |
| Master | NameNode, ResourceManager, JobHistory Server, WebAppProxy |
| Worker 1 | DataNode, Secondary NameNode, NodeManager |
| Worker 2–3 | DataNode, NodeManager |

## Подготовка

На каждой VM нужен один и тот же обычный пользователь, Java 11 и `curl`:

```bash
sudo apt-get update
sudo apt-get install -y openjdk-11-jdk-headless curl
```

Скопируйте репозиторий на все четыре VM. На каждой машине создайте
`cluster.env` из `cluster.env.example` и укажите одинаковые внутренние
адреса узлов:

```bash
cp cluster.env.example cluster.env
```

VM должны обращаться друг к другу по внутренней сети и иметь доступ к
`downloads.apache.org` для установки Hadoop. `cluster.env` исключён из Git.

## Запуск и проверка

Порядок команд для HDFS — в [hw1/README.md](hw1/README.md), для YARN —
в [hw2/README.md](hw2/README.md). Проверки включают состояние узлов,
веб-интерфейсы, `hdfs fsck /` и запуск MapReduce WordCount.

В группе безопасности разрешите SSH только с доверенных адресов и TCP между
четырьмя VM по внутренним адресам. Веб-интерфейсы не нужно открывать в
Интернет: их можно смотреть на VM через `localhost` или через SSH-проброс.

Конфигурация опирается на [руководство Apache по кластеру](https://hadoop.apache.org/docs/r3.4.1/hadoop-project-dist/hadoop-common/ClusterSetup.html)
и [совместимость Hadoop с Java](https://cwiki.apache.org/confluence/spaces/HADOOP/pages/100827883/Hadoop+Java+Versions).
