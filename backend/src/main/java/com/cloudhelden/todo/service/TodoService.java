package com.cloudhelden.todo.service;

import com.cloudhelden.todo.model.Todo;
import com.cloudhelden.todo.repository.TodoRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;
import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
public class TodoService {

    private final TodoRepository todoRepository;
    private final RedisTemplate<String, Object> redisTemplate;

    private static final String STATS_KEY = "todo:stats";

    @Cacheable(value = "todos", key = "'all'")
    public List<Todo> getAllTodos() {
        System.out.println("📊 Fetching from DATABASE (not cached)");
        incrementStat("db_reads");
        return todoRepository.findAll();
    }

    public Optional<Todo> getTodoById(Long id) {
        return todoRepository.findById(id);
    }

    @CacheEvict(value = "todos", allEntries = true)
    public Todo createTodo(Todo todo) {
        System.out.println("✅ Creating new Todo");
        incrementStat("todos_created");
        return todoRepository.save(todo);
    }

    @CacheEvict(value = "todos", allEntries = true)
    public Todo updateTodo(Long id, Todo todoDetails) {
        System.out.println("📝 Updating Todo: " + id);
        Todo todo = todoRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Todo not found"));

        todo.setTitle(todoDetails.getTitle());
        todo.setDescription(todoDetails.getDescription());
        todo.setCompleted(todoDetails.getCompleted());

        incrementStat("todos_updated");
        return todoRepository.save(todo);
    }

    @CacheEvict(value = "todos", allEntries = true)
    public void deleteTodo(Long id) {
        System.out.println("🗑️ Deleting Todo: " + id);
        todoRepository.deleteById(id);
        incrementStat("todos_deleted");
    }

    public List<Todo> getCompletedTodos() {
        return todoRepository.findByCompleted(true);
    }

    // Redis Statistics
    private void incrementStat(String statName) {
        String key = STATS_KEY + ":" + statName;
        redisTemplate.opsForValue().increment(key);
        redisTemplate.expire(key, 24, TimeUnit.HOURS);
    }

    public Object getStat(String statName) {
        String key = STATS_KEY + ":" + statName;
        Object value = redisTemplate.opsForValue().get(key);
        return value != null ? value : 0;
    }

    public void resetStats() {
        redisTemplate.keys(STATS_KEY + ":*").forEach(key -> redisTemplate.delete(key));
    }
}
