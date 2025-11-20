# Project Title
Multi-point KZG Proof Verification for the EVM

## Team
**Team/Individual Name:**  
protocolwhisper  

**GitHub Handle:**  
[@protocolwhisper](https://github.com/protocolwhisper)  

**Devfolio Handle:**  
protocolwhisper  

## Project Description
In Ethereum, blob data is verified using KZG commitments through the `kzg_point_evaluation` precompile, which runs a pairing check to confirm the proof’s validity.  
The thing is that each call costs around **50k gas**, so doing multiple evaluations adds up.  

With **multiproofs**, we could verify several points in one go with a single pairing operation improving performance and reducing costs.  
This project aims to make that possible by implementing multi-point KZG proof verification directly within the EVM execution layer.

## Tech Stack
- Rust  
- REVM  
- Solidity  
- Ethereum Precompiles  

## Objectives
- Implement a new precompile in **REVM** for multi-point KZG verification using the **BLS12-381** curve.  
- Develop and deploy a **smart contract** for on-chain verification, then **benchmark** its gas usage to measure savings compared to multiple single-point evaluations.

## Weekly progress

### Week 1  
- Pivoted the project direction.  
- Conducted research in cryptography and created [this notebook](https://github.com/protocolwhisper/arg25-Projects/blob/main/multikzg/assets/fromblobs.ipynb) explaining how blobs are mapped to finite fields.  
- Studied the multiproof algorithm by hand, covering all core concepts why it’s needed and what problem it solves 

### Week 2  
- Developed the [KZG implementation in Python](https://github.com/protocolwhisper/arg25-Projects/blob/main/multikzg/assets/python_impl/kzg.py) to improve prototyping and deepen understanding of the applied cryptography
- Presented a demo outlining the problem and identified a blocker related to the pairing verification the issue came from the EVM’s implementation, which uses a mirroring optimization (`-G₂`) in the pairing precompile, causing a mismatch with my Python version
- Added a [test](https://github.com/protocolwhisper/arg25-Projects/blob/main/multikzg/assets/python_impl/testkzg.py) to validate the Python implementation and align results with the EVM behavior
- Began implementing the precompile in REVM, but encountered issues when testing it against the Python implementation

### Week 3
 - Implementation of the precompile is in https://github.com/protocolwhisper/revm/blob/main/crates/precompile/src/kzg_multipoint_evaluation.rs
 - Contracts are available but the precompile it's not on any testnet cause limitations of pairing bls12381 availability but you can check the impl here https://github.com/protocolwhisper/arg25-Projects/blob/main/multikzg/assets/onchainmulti/src/KZGMultipointVerifier.sol




## References
- **KZG:** [https://dankradfeist.de/ethereum/2020/06/16/kate-polynomial-commitments.html](https://dankradfeist.de/ethereum/2020/06/16/kate-polynomial-commitments.html)  
- **REVM:** [https://github.com/bluealloy/revm/blob/main/crates/precompile/src/kzg_point_evaluation.rs](https://github.com/bluealloy/revm/blob/main/crates/precompile/src/kzg_point_evaluation.rs)  
- **EIP-4844:** [https://eips.ethereum.org/EIPS/eip-4844#point-evaluation-precompile](https://eips.ethereum.org/EIPS/eip-4844#point-evaluation-precompile)
