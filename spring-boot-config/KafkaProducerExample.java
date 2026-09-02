package com.example.kafka.producer;

import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Value;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.concurrent.CompletableFuture;

/**
 * Kafka Producer Service Example
 * Demonstrates how to send messages to Kafka topics
 */
@Service
public class KafkaProducerExample {

    private static final Logger logger = LoggerFactory.getLogger(KafkaProducerExample.class);

    private final KafkaTemplate<String, Object> kafkaTemplate;

    @Value("${kafka.topics.customer-events}")
    private String customerEventsTopic;

    @Value("${kafka.topics.order-events}")
    private String orderEventsTopic;

    public KafkaProducerExample(KafkaTemplate<String, Object> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    /**
     * Send a message to customer-events topic
     */
    public void sendCustomerEvent(String key, Object event) {
        sendMessage(customerEventsTopic, key, event);
    }

    /**
     * Send a message to order-events topic
     */
    public void sendOrderEvent(String key, Object event) {
        sendMessage(orderEventsTopic, key, event);
    }

    /**
     * Generic method to send message to any topic
     */
    public void sendMessage(String topic, String key, Object message) {
        logger.info("Sending message to topic: {} with key: {}", topic, key);

        CompletableFuture<SendResult<String, Object>> future = kafkaTemplate.send(topic, key, message);

        future.whenComplete((result, ex) -> {
            if (ex == null) {
                logger.info("Message sent successfully to topic: {} | Partition: {} | Offset: {}",
                        topic,
                        result.getRecordMetadata().partition(),
                        result.getRecordMetadata().offset());
            } else {
                logger.error("Failed to send message to topic: {} | Error: {}", topic, ex.getMessage());
            }
        });
    }

    /**
     * Send message with custom partition
     */
    public void sendMessageToPartition(String topic, int partition, String key, Object message) {
        logger.info("Sending message to topic: {} | Partition: {} | Key: {}", topic, partition, key);

        CompletableFuture<SendResult<String, Object>> future = 
            kafkaTemplate.send(topic, partition, key, message);

        future.whenComplete((result, ex) -> {
            if (ex == null) {
                logger.info("Message sent successfully | Offset: {}", 
                    result.getRecordMetadata().offset());
            } else {
                logger.error("Failed to send message: {}", ex.getMessage());
            }
        });
    }
}
