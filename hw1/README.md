# ДЗ №1 — HDFS

Конфигурация запускает один NameNode на `MASTER_HOST`, один Secondary NameNode
на `WORKER1_HOST` и три DataNode на рабочих VM.

## Порядок запуска

На каждой из четырёх VM из корня репозитория:

```bash
bash hw1/setup.sh
```

Скрипт проверяет Java 11, скачивает официальный облегчённый архив Hadoop
3.4.1 без AWS SDK, сверяет SHA-512 и записывает конфигурацию. S3 в этих
заданиях не используется. Скрипт не форматирует HDFS и не запускает демоны.

Только на новом, пустом NameNode:

```bash
bash hw1/format-once.sh
bash hw1/start.sh master
```

На первой рабочей VM:

```bash
bash hw1/start.sh worker-secondary
```

На второй и третьей рабочих VM:

```bash
bash hw1/start.sh worker
```

`format-once.sh` нельзя запускать повторно после создания кластера: повторное
форматирование удалит метаданные HDFS.

## Проверка

На NameNode:

```bash
bash hw1/check.sh
```

Скрипт проверяет число живых DataNode, отсутствие недореплицированных блоков,
`hdfs fsck /` и ответы веб-интерфейсов NameNode, Secondary NameNode и всех
трёх DataNode.
Ожидаются ровно три DataNode.
На первой рабочей VM дополнительно должны работать `DataNode` и
`SecondaryNameNode`, на двух остальных — `DataNode`; это можно проверить
через `jps`. Логи находятся в `~/teachbase-hadoop-logs`.

Веб-интерфейс NameNode доступен на `http://localhost:9870/` на главной VM,
Secondary NameNode — на `http://localhost:9868/` на первой рабочей VM,
DataNode — на `http://localhost:9864/` на каждой рабочей VM. Для просмотра
с другого компьютера используйте SSH-проброс порта, например:

```bash
ssh -L 9870:127.0.0.1:9870 USER@SSH_HOST
```

Здесь `SSH_HOST` — доступный SSH-адрес главной VM, а не
её внутренний адрес из `cluster.env`.
