# ДЗ №2 — YARN и веб-интерфейсы

Это задание использует HDFS-кластер из ДЗ №1. На главной VM работают
ResourceManager, JobHistory Server и WebAppProxy; на трёх рабочих VM —
NodeManager с сервисом `mapreduce_shuffle`.

## Порядок запуска

После запуска HDFS на каждой VM:

```bash
bash hw2/setup.sh
```

На главной VM:

```bash
bash hw2/start.sh master
```

На каждой рабочей VM:

```bash
bash hw2/start.sh worker
```

## Проверка

На главной VM:

```bash
bash hw2/check.sh
bash hw2/smoke.sh
```

Первый скрипт проверяет три NodeManager в состоянии `RUNNING` и ответы
веб-интерфейсов. Второй запускает MapReduce WordCount и сверяет результат:
`hadoop 2`, `hdfs 1`, `yarn 1`. Путь к тестовым данным в HDFS он печатает
после выполнения. Логи Hadoop находятся в `~/teachbase-hadoop-logs`.

## Веб-интерфейсы

Для проверки достаточно доступа через `localhost` на VM с соответствующим
демоном; публиковать веб-интерфейсы в Интернет не нужно.

| VM | Сервис | Локальный адрес |
| --- | --- | --- |
| Master | NameNode | `http://localhost:9870/` |
| Worker 1 | Secondary NameNode | `http://localhost:9868/` |
| Worker 1–3 | DataNode | `http://localhost:9864/` |
| Master | ResourceManager | `http://localhost:8088/` |
| Worker 1–3 | NodeManager | `http://localhost:8042/` |
| Master | JobHistory Server | `http://localhost:19888/` |
| Master | WebAppProxy | `http://localhost:9099/` |

Чтобы открыть интерфейс с другого компьютера, пробросьте нужный порт через
SSH. Например, для ResourceManager:

```bash
ssh -L 8088:127.0.0.1:8088 USER@SSH_HOST
```

Здесь `SSH_HOST` — доступный SSH-адрес главной VM.
