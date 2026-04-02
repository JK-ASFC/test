document.addEventListener('DOMContentLoaded', () => {
    const output = document.querySelector('#console pre');
    let osChoice = ""; // Initialisation du choix d'OS

    // Affichage de l'introduction
    const intro = `
Microsoft Windows [version 10.0.19045.5198]
(c) Microsoft Corporation. Tous droits réservés.

C:\\Users\\
`;

    output.innerText = intro;
    document.getElementById('commandInput').focus(); // Focus sur le champ de commande

    // Fonction de gestion des commandes
    function handleCommand(event) {
        if (event.key === 'Enter') {
            const input = document.getElementById('commandInput');
            const command = input.value.trim();
            input.value = ''; // Clear input field

            output.innerText += `\nC:\\Users\\ ${command}`;

            let response = '';

            // Commandes Windows
            if (osChoice === "windows") {
                if (command === 'ipconfig') {
                    response = `
Carte Ethernet Ethernet :
   Adresse IPv4. . . . . . . . . . . . . . : 192.168.1.10
   Masque de sous-réseau. . . . . . . . . : 255.255.255.0
   Passerelle par défaut. . . . . . . . . : 192.168.1.1
`;
                } else if (command === 'date') {
                    const currentDate = new Date().toLocaleDateString('fr-FR');
                    response = `La date actuelle est : ${currentDate}`;
                } else if (command === 'time') {
                    const currentTime = new Date().toLocaleTimeString('fr-FR');
                    response = `L'heure actuelle est : ${currentTime}`;
                } else {
                    response = `Commande non reconnue : ${command}`;
                }
            }

            // Commandes pour Linux et Mac
            else if (osChoice === "linux" || osChoice === "mac") {
                if (command === 'ifconfig' || command === 'ip a') {
                    response = `Adresse IP publique de votre machine : 192.168.0.1`;
                } else {
                    response = `Commande inconnue ou incompatible pour le système sélectionné.`;
                }
            }

            // Cas où aucun OS n'a été sélectionné
            else {
                response = `Système d'exploitation non sélectionné. Veuillez choisir Windows, Linux ou Mac.`;
            }

            output.innerText += `\n${response}`;
            output.scrollTop = output.scrollHeight; // Scroll automatique vers le bas
        }
    }

    // Fonction de sélection du système d'exploitation
    function chooseOS() {
        const inputElement = document.getElementById('commandInput');
        osChoice = inputElement.value.trim().toLowerCase();
        inputElement.value = ''; // Clear input field

        if (osChoice === "windows" || osChoice === "linux" || osChoice === "mac") {
            output.innerText += `\nOS choisi : ${osChoice}`;
        } else {
            output.innerText += `\nOS non reconnu, choisissez entre Windows, Linux ou Mac.`;
            osChoice = ""; // Reset si OS invalide
        }
    }

    // Appeler handleCommand lors de l'appui sur la touche Enter
    document.getElementById('commandInput').addEventListener('keydown', function(event) {
        // Si l'utilisateur appuie sur Entrée
        if (event.key === 'Enter') {
            event.preventDefault(); // Prévenir le comportement par défaut (par exemple, soumettre le formulaire)
            handleCommand(event); // Appeler la fonction handleCommand pour traiter la commande
        }
    });

    // Affichage du prompt
    function getPrompt() {
        if (osChoice === "windows") {
            return "C:\\Windows\\system32>";
        } else if (osChoice === "linux") {
            return "linux@linux:~$";
        } else if (osChoice === "mac") {
            return "mac@MacbookAir ~ %";
        } else {
            return ">"; // Par défaut
        }
    }
});
