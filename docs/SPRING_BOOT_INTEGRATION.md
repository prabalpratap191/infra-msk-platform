# Spring Boot Kafka Integration Guide

## Overview

This guide demonstrates how to integrate your Spring Boot microservices with the Kafka cluster provisioned by this infrastructure.

---

## Table of Contents

1. [Dependencies](#dependencies)
2. [Configuration](#configuration)
3. [Producer Implementation](#producer-implementation)
4. [Consumer Implementation](#consumer-implementation)
5. [Error Handling](#error-handling)
6. [Best Practices](#best-practices)

---

## Dependencies

### Maven (pom.xml)

```xml
<dependencies>
    <!-- Spring Kafka -->
    <dependency>
        <groupId>org.springframework.kafka</groupId>
        <artifactId>spring-kafka</artifactId>
    </dependency>
    
    <!-- Jackson for JSON serialization -->
    <dependency>
        <groupId>com.fasterxml.jackson.core</groupId>
        <artifactId>jackson-databind</artifactId>
    </dependency>
    
    <!-- Spring Boot Actuator (optional, for metrics) -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
</dependencies>
```

### Gradle (build.gradle)

```gradle
dependencies {
    implementation 'org.springframework.kafka:spring-kafka'
    implementation 'com.fasterxml.jackson.core:jackson-databind'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
}
```

---

## Configuration

### application.yml

See `kubernetes/spring-boot-example/application.yml` for complete configuration.

**Key configurations:**

```yaml
spring:
  kafka:
    bootstrap-servers: kafka-bootstrap.internal:9092
    producer:
      acks: all
      retries: 3
      enable-idempotence: true
    consumer:
      group-id: ${spring.application.name}-group
      auto-offset-reset: earliest
      enable-auto-commit: false
    listener:
      ack-mode: manual
```

### Kafka Configuration Class

```java
package com.meracommerce.config;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.apache.kafka.common.serialization.StringSerializer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
import org.springframework.kafka.core.*;
import org.springframework.kafka.listener.ContainerProperties;
import org.springframework.kafka.support.serializer.JsonDeserializer;
import org.springframework.kafka.support.serializer.JsonSerializer;

import java.util.HashMap;
import java.util.Map;

@Configuration
public class KafkaConfig {

    @Value("${spring.kafka.bootstrap-servers}")
    private String bootstrapServers;

    @Bean
    public ProducerFactory<String, Object> producerFactory() {
        Map<String, Object> config = new HashMap<>();
        config.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        config.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        config.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, JsonSerializer.class);
        config.put(ProducerConfig.ACKS_CONFIG, "all");
        config.put(ProducerConfig.RETRIES_CONFIG, 3);
        config.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);
        config.put(ProducerConfig.COMPRESSION_TYPE_CONFIG, "snappy");
        return new DefaultKafkaProducerFactory<>(config);
    }

    @Bean
    public KafkaTemplate<String, Object> kafkaTemplate() {
        return new KafkaTemplate<>(producerFactory());
    }

    @Bean
    public ConsumerFactory<String, Object> consumerFactory() {
        Map<String, Object> config = new HashMap<>();
        config.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        config.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
        config.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, JsonDeserializer.class);
        config.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        config.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false);
        config.put(JsonDeserializer.TRUSTED_PACKAGES, "*");
        return new DefaultKafkaConsumerFactory<>(config);
    }

    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, Object> kafkaListenerContainerFactory() {
        ConcurrentKafkaListenerContainerFactory<String, Object> factory = 
            new ConcurrentKafkaListenerContainerFactory<>();
        factory.setConsumerFactory(consumerFactory());
        factory.getContainerProperties().setAckMode(ContainerProperties.AckMode.MANUAL);
        factory.setConcurrency(3);
        return factory;
    }
}
```

---

## Producer Implementation

### Event Model

```java
package com.meracommerce.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CustomerEvent {
    @JsonProperty("event_id")
    private String eventId = UUID.randomUUID().toString();
    
    @JsonProperty("customer_id")
    private String customerId;
    
    @JsonProperty("event_type")
    private String eventType;
    
    @JsonProperty("payload")
    private Object payload;
    
    @JsonProperty("timestamp")
    private Instant timestamp = Instant.now();
}
```

### Producer Service

```java
package com.meracommerce.service;

import com.meracommerce.model.CustomerEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Service;
import org.springframework.util.concurrent.ListenableFuture;
import org.springframework.util.concurrent.ListenableFutureCallback;

@Slf4j
@Service
@RequiredArgsConstructor
public class CustomerEventProducer {

    private final KafkaTemplate<String, Object> kafkaTemplate;

    @Value("${kafka.topics.customer-events}")
    private String customerEventsTopic;

    public void publishCustomerEvent(CustomerEvent event) {
        log.info("Publishing customer event: {}", event.getEventId());
        
        ListenableFuture<SendResult<String, Object>> future = 
            kafkaTemplate.send(customerEventsTopic, event.getCustomerId(), event);
        
        future.addCallback(new ListenableFutureCallback<>() {
            @Override
            public void onSuccess(SendResult<String, Object> result) {
                log.info("Event published successfully: topic={}, partition={}, offset={}",
                    result.getRecordMetadata().topic(),
                    result.getRecordMetadata().partition(),
                    result.getRecordMetadata().offset());
            }

            @Override
            public void onFailure(Throwable ex) {
                log.error("Failed to publish event: {}", event.getEventId(), ex);
                // Implement retry logic or send to DLQ
            }
        });
    }
}
```

---

## Consumer Implementation

### Consumer Service

```java
package com.meracommerce.service;

import com.meracommerce.model.CustomerEvent;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class CustomerEventConsumer {

    @KafkaListener(
        topics = "${kafka.topics.customer-events}",
        groupId = "${spring.application.name}-group",
        containerFactory = "kafkaListenerContainerFactory"
    )
    public void consumeCustomerEvent(
            ConsumerRecord<String, CustomerEvent> record,
            Acknowledgment acknowledgment) {
        
        try {
            CustomerEvent event = record.value();
            log.info("Received customer event: eventId={}, type={}, offset={}",
                event.getEventId(), event.getEventType(), record.offset());
            
            // Process the event
            processEvent(event);
            
            // Manual acknowledgment
            acknowledgment.acknowledge();
            
            log.info("Successfully processed event: {}", event.getEventId());
            
        } catch (Exception ex) {
            log.error("Error processing event at offset {}: {}", 
                record.offset(), ex.getMessage(), ex);
            // Don't acknowledge - message will be reprocessed
            // Or send to DLQ after retry threshold
        }
    }
    
    private void processEvent(CustomerEvent event) {
        // Your business logic here
        switch (event.getEventType()) {
            case "CREATED":
                handleCustomerCreated(event);
                break;
            case "UPDATED":
                handleCustomerUpdated(event);
                break;
            case "DELETED":
                handleCustomerDeleted(event);
                break;
            default:
                log.warn("Unknown event type: {}", event.getEventType());
        }
    }
    
    private void handleCustomerCreated(CustomerEvent event) {
        log.info("Handling customer created: {}", event.getCustomerId());
        // Implementation
    }
    
    private void handleCustomerUpdated(CustomerEvent event) {
        log.info("Handling customer updated: {}", event.getCustomerId());
        // Implementation
    }
    
    private void handleCustomerDeleted(CustomerEvent event) {
        log.info("Handling customer deleted: {}", event.getCustomerId());
        // Implementation
    }
}
```

---

## Error Handling

### Dead Letter Queue (DLQ) Configuration

```java
@Component
public class KafkaErrorHandler {

    @Value("${kafka.topics.dead-letter-events}")
    private String dlqTopic;

    private final KafkaTemplate<String, Object> kafkaTemplate;

    public void sendToDLQ(ConsumerRecord<?, ?> record, Exception exception) {
        ErrorRecord errorRecord = ErrorRecord.builder()
            .originalTopic(record.topic())
            .partition(record.partition())
            .offset(record.offset())
            .key(record.key())
            .value(record.value())
            .exception(exception.getMessage())
            .timestamp(Instant.now())
            .build();
        
        kafkaTemplate.send(dlqTopic, errorRecord);
    }
}
```

---

## Best Practices

### 1. **Idempotent Producers**
```java
config.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);
```

### 2. **Manual Acknowledgment**
```java
acknowledgment.acknowledge(); // Only after successful processing
```

### 3. **Proper Serialization**
```java
config.put(JsonDeserializer.TRUSTED_PACKAGES, "com.meracommerce.*");
```

### 4. **Health Checks**
```java
@Component
public class KafkaHealthIndicator implements HealthIndicator {
    @Override
    public Health health() {
        // Check Kafka connectivity
        return Health.up().build();
    }
}
```

### 5. **Metrics**
```yaml
management:
  metrics:
    export:
      prometheus:
        enabled: true
```

---

## Testing

### Integration Test

```java
@SpringBootTest
@EmbeddedKafka
class KafkaIntegrationTest {
    
    @Autowired
    private CustomerEventProducer producer;
    
    @Test
    void testProduceAndConsume() {
        CustomerEvent event = new CustomerEvent();
        event.setCustomerId("CUST-123");
        event.setEventType("CREATED");
        
        producer.publishCustomerEvent(event);
        
        // Assertions
    }
}
```

---

## Connection from EKS

Ensure your deployment uses the ConfigMap:

```yaml
envFrom:
  - configMapRef:
      name: kafka-config
  - secretRef:
      name: kafka-secret
```

See `kubernetes/spring-boot-example/values.yaml` for complete Helm configuration.

---

## Support

For issues:
- Review logs: `kubectl logs <pod-name>`
- Check Kafka connectivity: `kafka-broker-api-versions --bootstrap-server kafka-bootstrap.internal:9092`
- Contact: devops@meracommerce.com
