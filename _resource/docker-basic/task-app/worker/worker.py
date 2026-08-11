import os
import json
import time
import redis
from datetime import datetime

REDIS_HOST = os.getenv('REDIS_HOST', 'localhost')
REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))

def connect_redis():
    """Connect to Redis with retry logic."""
    max_retries = 10
    for i in range(max_retries):
        try:
            client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)
            client.ping()
            print(f"Connected to Redis at {REDIS_HOST}:{REDIS_PORT}")
            return client
        except redis.ConnectionError as e:
            print(f"Redis connection failed (attempt {i+1}/{max_retries}): {e}")
            time.sleep(2)
    raise Exception("Could not connect to Redis")

def process_job(job_data):
    """Process a single job from the queue."""
    try:
        job = json.loads(job_data)
        job_type = job.get('type', 'unknown')
        task = job.get('task', {})
        timestamp = job.get('timestamp', datetime.now().isoformat())
        
        # Simulate processing
        print(f"[{timestamp}] Processing {job_type}:")
        print(f"  Task ID: {task.get('id', 'N/A')}")
        print(f"  Title: {task.get('title', 'N/A')}")
        print(f"  Status: {task.get('status', 'N/A')}")
        
        # In a real app, you might:
        # - Send email notifications
        # - Update search indexes
        # - Trigger webhooks
        # - Generate reports
        
        time.sleep(0.5)  # Simulate work
        print(f"  ✓ Job completed\n")
        return True
        
    except json.JSONDecodeError as e:
        print(f"Invalid job data: {e}")
        return False
    except Exception as e:
        print(f"Job processing error: {e}")
        return False

def main():
    """Main worker loop."""
    print("Task Worker starting...")
    print(f"Connecting to Redis at {REDIS_HOST}:{REDIS_PORT}")
    
    client = connect_redis()
    print("Worker ready. Waiting for jobs...")
    
    while True:
        try:
            # BRPOP blocks until a job is available (timeout: 5 seconds)
            result = client.brpop('task_queue', timeout=5)
            
            if result:
                queue_name, job_data = result
                process_job(job_data)
            else:
                # No job received, just continue waiting
                pass
                
        except redis.ConnectionError as e:
            print(f"Redis connection lost: {e}")
            print("Reconnecting...")
            time.sleep(2)
            client = connect_redis()
        except KeyboardInterrupt:
            print("\nWorker shutting down...")
            break
        except Exception as e:
            print(f"Unexpected error: {e}")
            time.sleep(1)

if __name__ == '__main__':
    main()
