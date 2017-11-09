FROM python:2.7

ARG artifact_root="."

COPY $artifact_root/entrypoint.sh /entrypoint.sh
COPY $artifact_root/uni.txt /uni.txt
COPY $artifact_root/post.file /post.file

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]