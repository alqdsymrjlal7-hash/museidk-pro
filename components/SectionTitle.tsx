export default function SectionTitle({eyebrow,title,description}:{eyebrow?:string;title:string;description?:string}) {
 return <div className="section-title">{eyebrow && <span className="eyebrow">{eyebrow}</span>}<h1>{title}</h1>{description && <p>{description}</p>}</div>;
}