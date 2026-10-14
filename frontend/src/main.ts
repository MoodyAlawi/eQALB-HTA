import { createApp } from 'vue'
import App from './App.vue'
import './styles.css'
// The landing page's own stylesheet, loaded after the app's so its scoped rules
// win where the two meet. See the file header for how it stays scoped.
import './landing.css'

createApp(App).mount('#app')
