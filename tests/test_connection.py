"""RabbitMQ 연결 테스트"""
import pika
import pytest


class TestRabbitMQConnection:
    """RabbitMQ 연결 테스트"""

    def test_connection_success(self):
        """RabbitMQ에 정상 연결되는가?"""
        # Given: RabbitMQ 연결 정보
        credentials = pika.PlainCredentials("guest", "guest")
        parameters = pika.ConnectionParameters(
            host="localhost",
            port=5672,
            credentials=credentials,
        )

        # When: 연결 시도
        connection = pika.BlockingConnection(parameters)

        # Then: 연결 성공
        assert connection.is_open
        connection.close()

    def test_channel_creation(self):
        """채널 생성이 되는가?"""
        # Given: RabbitMQ 연결
        credentials = pika.PlainCredentials("guest", "guest")
        parameters = pika.ConnectionParameters(
            host="localhost",
            port=5672,
            credentials=credentials,
        )
        connection = pika.BlockingConnection(parameters)

        # When: 채널 생성
        channel = connection.channel()

        # Then: 채널 열림
        assert channel.is_open
        connection.close()

    def test_connection_wrong_credentials(self):
        """잘못된 인증정보로 연결 실패하는가?"""
        # Given: 잘못된 인증정보
        credentials = pika.PlainCredentials("wrong", "wrong")
        parameters = pika.ConnectionParameters(
            host="localhost",
            port=5672,
            credentials=credentials,
        )

        # When/Then: 연결 실패
        with pytest.raises(pika.exceptions.ProbableAuthenticationError):
            pika.BlockingConnection(parameters)
