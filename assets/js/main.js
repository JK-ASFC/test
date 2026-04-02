function checkCode() {
    const code = document.getElementById('code').value;
    const errorMessage = document.getElementById('error-message');

    if (code === '1234') {
        window.location.href = 'portfolio.html'; // Remplacer par ton fichier d'accueil
    } else {
        errorMessage.textContent = 'Code incorrect, veuillez réessayer.';
    }
}
document.getElementById("code").addEventListener("keypress", function(event) {
    // Si l'utilisateur appuie sur la touche Entrée (code 13)
    if (event.key === "Enter") {
        checkCode(); // Appeler la fonction checkCode pour valider
    }
});

// Ajouter un événement de clic sur le bouton "Entrer"
document.getElementById("submitBtn").addEventListener("click", function() {
    checkCode(); // Appeler la fonction checkCode lors du clic
});

// Fonction pour afficher la date et l'heure actuelles
function updateDateTime() {
    const now = new Date();
    const options = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
    const date = now.toLocaleDateString('fr-FR', options);
    const time = now.toLocaleTimeString('fr-FR');

    document.getElementById('datetime').innerHTML = `${date} - ${time}`;
}

// Mettre à jour l'heure toutes les secondes
setInterval(updateDateTime, 1000);

// Initialiser l'affichage dès le chargement de la page
updateDateTime();

// Animation simple sur les photos des personnes dans l'organigramme
document.querySelectorAll('.person img').forEach((img) => {
    img.addEventListener('click', () => {
        alert('Détails à venir pour : ' + img.alt);
    });
});

