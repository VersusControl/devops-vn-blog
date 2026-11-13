# AWS Emulator image, based on the Dockerfile in the AWS Emulator User Guide.
# AWS does not publish a prebuilt image, so you build this one yourself.
#
#   Intel/AMD:            docker build -t aws-emulator .
#   Apple silicon / Arm:  docker build --build-arg EMULATOR_ARCH=aarch64 -t aws-emulator .
FROM public.ecr.aws/amazonlinux/amazonlinux:2023-minimal

ARG EMULATOR_ARCH=x86_64
ADD https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS/latest/aws-emulator-${EMULATOR_ARCH}.rpm /tmp/aws-emulator.rpm

RUN rpm -i /tmp/aws-emulator.rpm && rm /tmp/aws-emulator.rpm \
    && mkdir -p /home/emulator && chown 1000 /home/emulator

USER 1000
ENV HOME=/home/emulator
EXPOSE 9297

# -b 0.0.0.0 lets Docker forward the port. Publish it on 127.0.0.1 only (see start-emulator.sh).
ENTRYPOINT ["aws-emulator", "-b", "0.0.0.0"]
