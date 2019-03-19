FROM docker.elastic.co/elasticsearch/elasticsearch:6.3.2
ADD ./elasticsearch.yml /usr/share/elasticsearch/config/
USER root
RUN chown elasticsearch:elasticsearch config/elasticsearch.yml
USER elasticsearch