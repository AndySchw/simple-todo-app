// API Configuration
const API_URL = window.location.hostname === 'localhost'
    ? 'http://localhost:8080/api/todos'
    : '/api/todos';

// Load todos on page load
document.addEventListener('DOMContentLoaded', () => {
    loadTodos();
    loadStats();
    checkBackendHealth();

    // Refresh stats every 5 seconds
    setInterval(loadStats, 5000);
});

// Check backend health
async function checkBackendHealth() {
    try {
        const response = await fetch(`${API_URL}/health`);
        const data = await response.json();
        document.getElementById('backendStatus').textContent = data.status;
        document.getElementById('backendStatus').style.color = '#4ade80';
    } catch (error) {
        document.getElementById('backendStatus').textContent = 'OFFLINE';
        document.getElementById('backendStatus').style.color = '#ff6b6b';
    }
}

// Load all todos
async function loadTodos() {
    try {
        const response = await fetch(API_URL);
        const todos = await response.json();

        const todoList = document.getElementById('todoList');

        if (todos.length === 0) {
            todoList.innerHTML = '<div class="empty-state">Keine Todos vorhanden. Erstelle dein erstes Todo! 🎉</div>';
            return;
        }

        todoList.innerHTML = todos.map(todo => `
            <div class="todo-item ${todo.completed ? 'completed' : ''}">
                <input
                    type="checkbox"
                    class="todo-checkbox"
                    ${todo.completed ? 'checked' : ''}
                    onchange="toggleTodo(${todo.id}, ${!todo.completed})"
                />
                <div class="todo-content">
                    <div class="todo-title">${escapeHtml(todo.title)}</div>
                    ${todo.description ? `<div class="todo-description">${escapeHtml(todo.description)}</div>` : ''}
                    <div class="todo-meta">
                        Erstellt: ${formatDate(todo.createdAt)} |
                        Aktualisiert: ${formatDate(todo.updatedAt)}
                    </div>
                </div>
                <div class="todo-actions">
                    <button class="delete-btn" onclick="deleteTodo(${todo.id})">🗑️ Löschen</button>
                </div>
            </div>
        `).join('');

    } catch (error) {
        console.error('Error loading todos:', error);
        document.getElementById('todoList').innerHTML =
            '<div class="loading">Fehler beim Laden der Todos ❌</div>';
    }
}

// Load statistics
async function loadStats() {
    try {
        const response = await fetch(`${API_URL}/stats`);
        const stats = await response.json();

        document.getElementById('statsCreated').textContent = stats.todos_created || 0;
        document.getElementById('statsUpdated').textContent = stats.todos_updated || 0;
        document.getElementById('statsDeleted').textContent = stats.todos_deleted || 0;
        document.getElementById('statsDbReads').textContent = stats.db_reads || 0;
    } catch (error) {
        console.error('Error loading stats:', error);
    }
}

// Add new todo
async function addTodo() {
    const title = document.getElementById('todoTitle').value.trim();
    const description = document.getElementById('todoDescription').value.trim();

    if (!title) {
        alert('Bitte gib einen Titel ein!');
        return;
    }

    try {
        const response = await fetch(API_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                title: title,
                description: description,
                completed: false
            })
        });

        if (response.ok) {
            document.getElementById('todoTitle').value = '';
            document.getElementById('todoDescription').value = '';
            await loadTodos();
            await loadStats();
        }
    } catch (error) {
        console.error('Error adding todo:', error);
        alert('Fehler beim Hinzufügen des Todos!');
    }
}

// Toggle todo completion
async function toggleTodo(id, completed) {
    try {
        // First get the current todo
        const response = await fetch(`${API_URL}/${id}`);
        const todo = await response.json();

        // Update with new completion status
        await fetch(`${API_URL}/${id}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                ...todo,
                completed: completed
            })
        });

        await loadTodos();
        await loadStats();
    } catch (error) {
        console.error('Error toggling todo:', error);
    }
}

// Delete todo
async function deleteTodo(id) {
    if (!confirm('Möchtest du dieses Todo wirklich löschen?')) {
        return;
    }

    try {
        await fetch(`${API_URL}/${id}`, {
            method: 'DELETE'
        });

        await loadTodos();
        await loadStats();
    } catch (error) {
        console.error('Error deleting todo:', error);
        alert('Fehler beim Löschen des Todos!');
    }
}

// Reset statistics
async function resetStats() {
    if (!confirm('Möchtest du die Statistiken wirklich zurücksetzen?')) {
        return;
    }

    try {
        await fetch(`${API_URL}/stats/reset`, {
            method: 'POST'
        });

        await loadStats();
    } catch (error) {
        console.error('Error resetting stats:', error);
    }
}

// Helper functions
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleString('de-DE', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

// Enter key support
document.addEventListener('keypress', (e) => {
    if (e.key === 'Enter' && (e.target.id === 'todoTitle' || e.target.id === 'todoDescription')) {
        addTodo();
    }
});
