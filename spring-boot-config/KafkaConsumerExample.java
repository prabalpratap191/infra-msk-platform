package com.example.kafka.consumer;

import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Service;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Kafka Consumer Service Example
 * Demonstrates how to consume messages from Kafka topics
 */
@Service
public class KafkaConsumerExample {

    private static final Logger logger = LoggerFactory.getLogger(KafkaConsumerExample.class);

    /**
     * Consumer for customer-events topic
     */
    @KafkaListener(
        topics = "${kafka.topics.customer-events}",
        groupId = "customer-service-group",
        concurrency = "3"
    )
    public void consumeCustomerEvents(
            @Payload String message,
            @Header(KafkaHeaders.RECEIVED_KEY) String key,
            @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
            @Header(KafkaHeaders.OFFSET) long offset,
            Acknowledgment acknowledgment) {

        try {
            logger.info("Received customer event | Key: {} | Partition: {} | Offset: {}", 
                key, partition, offset);
            logger.info("Message: {}", message);

            // Process the message
            processCustomerEvent(message);

            // Manually acknowledge the message
            acknowledgment.acknowledge();
            logger.info("Message processed and acknowledged successfully");

        } catch (Exception e) {
            logger.error("Error processing customer event | Key: {} | Error: {}", key, e.getMessage());
            // Optionally send to dead-letter topic
            // Do not acknowledge - message will be reprocessed
        }
    }

    /**
     * Consumer for order-events topic
     */
    @KafkaListener(
        topics = "${kafka.topics.order-events}",
        groupId = "order-service-group",
        concurrency = "3"
    )
    public void consumeOrderEvents(
            @Payload String message,
            @Header(KafkaHeaders.RECEIVED_KEY) String key,
            @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
            @Header(KafkaHeaders.OFFSET) long offset,
            Acknowledgment acknowledgment) {

        try {
            logger.info("Received order event | Key: {} | Partition: {} | Offset: {}", 
                key, partition, offset);
            logger.info("Message: {}", message);

            // Process the message
            processOrderEvent(message);

            // Manually acknowledge
            acknowledgment.acknowledge();
            logger.info("Message processed and acknowledged successfully");

        } catch (Exception e) {
            logger.error("Error processing order event | Key: {} | Error: {}", key, e.getMessage());
        }
    }

    /**
     * Consumer for payment-events topic with batch processing
     */
    @KafkaListener(
        topics = "${kafka.topics.payment-events}",
        groupId = "payment-service-group",
        containerFactory = "kafkaBatchListenerContainerFactory"
    )
    public void consumePaymentEventsBatch(
            @Payload java.util.List<String> messages,
            Acknowledgment acknowledgment) {

        try {
            logger.info("Received batch of {} payment events", messages.size());

            // Process batch
            messages.forEach(this::processPaymentEvent);

            // Acknowledge batch
            acknowledgment.acknowledge();
            logger.info("Batch processed and acknowledged successfully");

        } catch (Exception e) {
            logger.error("Error processing payment events batch: {}", e.getMessage());
        }
    }

    /**
     * Dead Letter Queue consumer
     */
    @KafkaListener(
        topics = "${kafka.topics.dead-letter-events}",
        groupId = "dlq-handler-group"
    )
    public void consumeDeadLetterEvents(
            @Payload String message,
            @Header(KafkaHeaders.RECEIVED_KEY) String key,
            Acknowledgment acknowledgment) {

        logger.warn("Received dead letter event | Key: {}", key);
        logger.warn("Failed message: {}", message);

        // Handle failed messages (log, alert, retry with backoff, etc.)
        handleDeadLetterEvent(message);

        acknowledgment.acknowledge();
    }

    // Business logic methods
    private void processCustomerEvent(String message) {
        // Implement customer event processing logic
        logger.debug("Processing customer event: {}", message);
    }

    private void processOrderEvent(String message) {
        // Implement order event processing logic
        logger.debug("Processing order event: {}", message);
    }

    private void processPaymentEvent(String message) {
        // Implement payment event processing logic
        logger.debug("Processing payment event: {}", message);
    }

    private void handleDeadLetterEvent(String message) {
        // Implement dead letter handling logic
        logger.debug("Handling dead letter event: {}", message);
    }
}
