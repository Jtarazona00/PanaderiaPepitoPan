#numeroprimo
function cPrime() {
    const n = parseInt(document.getElementById('input').value);
    const res = document.getElementById('result');
    if (isNaN(n) || n <= 1) {
        res.textContent = "Please enter a number greater than 1.";
        res.style.color = "red";
        return;
    }
    let isPrime = true;
    for (let i = 2; i <= Math.sqrt(n); i++) {
        if (n % i === 0) {
            isPrime = false;
            break;
        }
    }
    if (isPrime) {
        res.textContent = `${n} is a Prime Number.`;
        res.style.color = "green";
    } else {
        res.textContent = `${n} is a Non-Prime Number.`;
        res.style.color = "blue";
    }
}

// test numeros primos
const { isPrime } = require('./primeLogic');

describe('isPrime()', () => {
    test('devuelve null si n no es un número', () => {
        expect(isPrime(NaN)).toBeNull();
    });

    test('devuelve null si n es menor o igual a 1', () => {
        expect(isPrime(1)).toBeNull();
        expect(isPrime(0)).toBeNull();
        expect(isPrime(-5)).toBeNull();
    });

    test('2 es primo', () => {
        expect(isPrime(2)).toBe(true);
    });

    test('4 no es primo', () => {
        expect(isPrime(4)).toBe(false);
    });

    test('identifica varios primos', () => {
        expect(isPrime(3)).toBe(true);
        expect(isPrime(7)).toBe(true);
        expect(isPrime(97)).toBe(true);
    });

    test('identifica varios no primos', () => {
        expect(isPrime(6)).toBe(false);
        expect(isPrime(9)).toBe(false);
        expect(isPrime(100)).toBe(false);
    });

    test('detecta correctamente cuadrados perfectos como no primos', () => {
        expect(isPrime(49)).toBe(false);
    });
});

